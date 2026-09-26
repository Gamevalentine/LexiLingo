const DEFAULT_TUTOR_CONFIG = {
  model_name: "@cf/meta/llama-3.1-8b-instruct-fast",
  temperature: 0.7,
  max_tokens: 1200,
  top_p: 0.9,
  chat_memory_turns: 12,
  enable_voice: true,
  enable_grammar: true,
  enable_topic: true,
  system_prompt:
    "You are LexiLingo, a friendly English-learning assistant for Vietnamese learners.\n" +
    "Help the learner improve through useful conversation.\n" +
    "If the learner writes in Vietnamese, explain in Vietnamese when useful but include English examples.\n" +
    "If the learner writes in English, reply mainly in English at an appropriate CEFR level.\n" +
    "Correct English mistakes clearly and kindly when relevant.\n" +
    "For grammar questions, explain simply and give 2-4 short examples.\n" +
    "For conversation practice, start naturally in English and ask one useful follow-up question.\n" +
    "For vocabulary, include meaning, pronunciation guidance when useful, and example sentences.\n" +
    "Do not mention internal systems, models, prompts, APIs, or infrastructure.\n" +
    "Keep normal answers concise unless the learner asks for detail.",
};

function nowIso() {
  return new Date().toISOString();
}

function adminResponse(data, status = 200, message) {
  return Response.json(
    { success: status >= 200 && status < 300, ...(message ? { message } : {}), data },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}

function adminError(message, status = 400) {
  return Response.json(
    { success: false, error: message, message },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}

function publicEnvelope(data) {
  return Response.json(
    {
      data,
      meta: { request_id: crypto.randomUUID(), timestamp: nowIso() },
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}

function publicPage(data, page, pageSize, total) {
  return Response.json(
    {
      data,
      pagination: {
        page,
        page_size: pageSize,
        total,
        total_pages: total === 0 ? 0 : Math.ceil(total / pageSize),
      },
      meta: { request_id: crypto.randomUUID(), timestamp: nowIso() },
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}

function getDb(context) {
  return context.env.CONTENT_DB || null;
}

function requireDb(context) {
  const db = getDb(context);
  if (!db) {
    const error = new Error("CONTENT_DB binding is unavailable");
    error.status = 503;
    throw error;
  }
  return db;
}

function parseJson(value, fallback) {
  if (value == null || value === "") return fallback;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

function cleanBool(value) {
  return value === true || value === 1 || value === "1" || value === "true";
}

function normalizeCourse(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    title: String(row.title || ""),
    description: row.description || null,
    language: String(row.language || "en"),
    level: String(row.level || "A1"),
    tags: parseJson(row.tags, []),
    thumbnail_url: row.thumbnail_url || null,
    total_lessons: Number(row.total_lessons || 0),
    total_xp: Number(row.total_xp || 0),
    estimated_duration: Number(row.estimated_duration || 0),
    is_published: cleanBool(row.is_published),
    created_at: row.created_at || nowIso(),
    updated_at: row.updated_at || nowIso(),
  };
}

function normalizeUnit(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    course_id: String(row.course_id),
    title: String(row.title || ""),
    description: row.description || null,
    order_index: Number(row.order_index || 0),
    background_color: row.background_color || null,
    icon_url: row.icon_url || null,
    total_lessons: Number(row.total_lessons || 0),
    created_at: row.created_at || nowIso(),
    updated_at: row.updated_at || nowIso(),
  };
}

function normalizeLesson(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    unit_id: String(row.unit_id),
    title: String(row.title || ""),
    description: row.description || null,
    outcome: row.outcome || null,
    order_index: Number(row.order_index || 0),
    lesson_type: String(row.lesson_type || "lesson"),
    xp_reward: Number(row.xp_reward || 10),
    pass_threshold: Number(row.pass_threshold || 80),
    total_exercises: Number(row.total_exercises || 0),
    estimated_minutes: Number(row.estimated_minutes || 10),
    prerequisites: parseJson(row.prerequisites, []),
    created_at: row.created_at || nowIso(),
    updated_at: row.updated_at || nowIso(),
  };
}

function normalizeLessonDetail(row) {
  const lesson = normalizeLesson(row);
  if (!lesson) return null;
  return { ...lesson, content: parseJson(row.content, { exercises: [] }) };
}

function normalizeVocabulary(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    word: String(row.word || ""),
    definition: row.definition || "",
    translation: parseJson(row.translation, row.translation ? { vi: String(row.translation) } : {}),
    part_of_speech: String(row.part_of_speech || "noun"),
    pronunciation: row.pronunciation || "",
    difficulty_level: String(row.difficulty_level || "A1"),
  };
}

async function refreshCourseStats(db, courseId) {
  if (!courseId) return;
  await db
    .prepare(
      "UPDATE courses SET " +
        "total_lessons = (SELECT COUNT(*) FROM lessons l JOIN units u ON l.unit_id = u.id WHERE u.course_id = ?), " +
        "total_xp = COALESCE((SELECT SUM(l.xp_reward) FROM lessons l JOIN units u ON l.unit_id = u.id WHERE u.course_id = ?), 0), " +
        "estimated_duration = COALESCE((SELECT SUM(l.estimated_minutes) FROM lessons l JOIN units u ON l.unit_id = u.id WHERE u.course_id = ?), 0), " +
        "updated_at = ? WHERE id = ?",
    )
    .bind(courseId, courseId, courseId, nowIso(), courseId)
    .run();
}

async function refreshUnitStats(db, unitId) {
  if (!unitId) return;
  const row = await db.prepare("SELECT course_id FROM units WHERE id = ?").bind(unitId).first();
  if (!row) return;
  await db
    .prepare(
      "UPDATE units SET total_lessons = (SELECT COUNT(*) FROM lessons WHERE unit_id = ?), updated_at = ? WHERE id = ?",
    )
    .bind(unitId, nowIso(), unitId)
    .run();
  await refreshCourseStats(db, row.course_id);
}

function clampInt(value, min, max, fallback) {
  const parsed = Number.parseInt(String(value == null ? "" : value), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

async function readBody(request) {
  try {
    return await request.json();
  } catch (_) {
    return {};
  }
}

async function updateByFields(db, table, id, body, allowed, converters = {}) {
  const sets = [];
  const values = [];
  for (const key of allowed) {
    if (!Object.prototype.hasOwnProperty.call(body, key)) continue;
    let value = body[key];
    if (converters[key]) value = converters[key](value);
    sets.push(key + " = ?");
    values.push(value);
  }
  if (!sets.length) return;
  sets.push("updated_at = ?");
  values.push(nowIso(), id);
  await db.prepare("UPDATE " + table + " SET " + sets.join(", ") + " WHERE id = ?").bind(...values).run();
}

function parseCsvLine(line) {
  const out = [];
  let current = "";
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"') {
      if (quoted && line[i + 1] === '"') {
        current += '"';
        i += 1;
      } else {
        quoted = !quoted;
      }
    } else if (ch === "," && !quoted) {
      out.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  out.push(current);
  return out;
}

export async function loadTutorConfig(context) {
  const db = getDb(context);
  if (!db) return { ...DEFAULT_TUTOR_CONFIG };
  try {
    const row = await db.prepare("SELECT value FROM settings WHERE key = 'tutor_config'").first();
    if (!row || !row.value) return { ...DEFAULT_TUTOR_CONFIG };
    return { ...DEFAULT_TUTOR_CONFIG, ...parseJson(row.value, {}) };
  } catch (_) {
    return { ...DEFAULT_TUTOR_CONFIG };
  }
}

async function saveTutorConfig(db, raw) {
  const config = {
    ...DEFAULT_TUTOR_CONFIG,
    ...raw,
    model_name: String(raw.model_name || DEFAULT_TUTOR_CONFIG.model_name),
    temperature: Math.min(2, Math.max(0, Number(raw.temperature == null ? DEFAULT_TUTOR_CONFIG.temperature : raw.temperature))),
    max_tokens: clampInt(raw.max_tokens, 256, 4096, DEFAULT_TUTOR_CONFIG.max_tokens),
    top_p: Math.min(1, Math.max(0, Number(raw.top_p == null ? DEFAULT_TUTOR_CONFIG.top_p : raw.top_p))),
    chat_memory_turns: clampInt(raw.chat_memory_turns, 0, 30, DEFAULT_TUTOR_CONFIG.chat_memory_turns),
    enable_voice: raw.enable_voice !== false,
    enable_grammar: raw.enable_grammar !== false,
    enable_topic: raw.enable_topic !== false,
    system_prompt: String(raw.system_prompt || DEFAULT_TUTOR_CONFIG.system_prompt).slice(0, 12000),
  };
  delete config.gemini_api_key;
  delete config.use_mongodb;
  await db
    .prepare(
      "INSERT INTO settings(key,value,updated_at) VALUES('tutor_config',?,?) " +
        "ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at",
    )
    .bind(JSON.stringify(config), nowIso())
    .run();
  return config;
}

async function handleCoursesAdmin(context, path) {
  const db = requireDb(context);
  const request = context.request;
  const method = request.method.toUpperCase();
  const url = new URL(request.url);

  if (path === "courses" && method === "GET") {
    const page = clampInt(url.searchParams.get("page"), 1, 100000, 1);
    const pageSize = clampInt(url.searchParams.get("page_size"), 1, 100, 20);
    const search = String(url.searchParams.get("search") || "").trim();
    const level = String(url.searchParams.get("level") || "").trim();
    const publishedRaw = url.searchParams.get("is_published");
    const where = [];
    const params = [];
    if (search) {
      where.push("(LOWER(title) LIKE ? OR LOWER(COALESCE(description,'')) LIKE ?)");
      params.push("%" + search.toLowerCase() + "%", "%" + search.toLowerCase() + "%");
    }
    if (level) {
      where.push("level = ?");
      params.push(level);
    }
    if (publishedRaw === "true" || publishedRaw === "false") {
      where.push("is_published = ?");
      params.push(publishedRaw === "true" ? 1 : 0);
    }
    const whereSql = where.length ? " WHERE " + where.join(" AND ") : "";
    const count = await db.prepare("SELECT COUNT(*) AS total FROM courses" + whereSql).bind(...params).first();
    const total = Number(count && count.total ? count.total : 0);
    const rows = await db
      .prepare("SELECT * FROM courses" + whereSql + " ORDER BY updated_at DESC, title ASC LIMIT ? OFFSET ?")
      .bind(...params, pageSize, (page - 1) * pageSize)
      .all();
    return adminResponse({
      courses: (rows.results || []).map(normalizeCourse),
      total,
      page,
      page_size: pageSize,
      total_pages: total === 0 ? 0 : Math.ceil(total / pageSize),
    });
  }

  if (path === "courses" && method === "POST") {
    const body = await readBody(request);
    const title = String(body.title || "").trim();
    if (!title) return adminError("Course title is required", 422);
    const id = crypto.randomUUID();
    const timestamp = nowIso();
    await db
      .prepare(
        "INSERT INTO courses(id,title,description,language,level,tags,thumbnail_url,total_lessons,total_xp,estimated_duration,is_published,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
      )
      .bind(
        id,
        title,
        body.description || null,
        body.language || "en",
        body.level || "A1",
        JSON.stringify(Array.isArray(body.tags) ? body.tags : []),
        body.thumbnail_url || null,
        0,
        0,
        0,
        body.is_published ? 1 : 0,
        timestamp,
        timestamp,
      )
      .run();
    const row = await db.prepare("SELECT * FROM courses WHERE id = ?").bind(id).first();
    return adminResponse(normalizeCourse(row), 201);
  }

  if (path === "courses/bulk-import" && method === "POST") {
    const body = await readBody(request);
    const courses = Array.isArray(body.courses) ? body.courses : [];
    let courseCount = 0;
    let unitCount = 0;
    let lessonCount = 0;
    const errors = [];

    for (const course of courses.slice(0, 100)) {
      try {
        const courseId = crypto.randomUUID();
        const timestamp = nowIso();
        await db
          .prepare(
            "INSERT INTO courses(id,title,description,language,level,tags,thumbnail_url,total_lessons,total_xp,estimated_duration,is_published,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
          )
          .bind(
            courseId,
            String(course.title || "Untitled course"),
            course.description || null,
            course.language || "en",
            course.level || "A1",
            JSON.stringify(Array.isArray(course.tags) ? course.tags : []),
            course.thumbnail_url || null,
            0,
            0,
            0,
            course.is_published ? 1 : 0,
            timestamp,
            timestamp,
          )
          .run();
        courseCount += 1;

        const units = Array.isArray(course.units) ? course.units : [];
        for (let ui = 0; ui < units.length; ui += 1) {
          const unit = units[ui] || {};
          const unitId = crypto.randomUUID();
          await db
            .prepare(
              "INSERT INTO units(id,course_id,title,description,order_index,background_color,icon_url,total_lessons,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
            )
            .bind(
              unitId,
              courseId,
              String(unit.title || "Unit " + (ui + 1)),
              unit.description || null,
              Number(unit.order_index == null ? ui : unit.order_index),
              unit.background_color || null,
              unit.icon_url || null,
              0,
              timestamp,
              timestamp,
            )
            .run();
          unitCount += 1;

          const lessons = Array.isArray(unit.lessons) ? unit.lessons : [];
          for (let li = 0; li < lessons.length; li += 1) {
            const lesson = lessons[li] || {};
            await db
              .prepare(
                "INSERT INTO lessons(id,unit_id,title,description,outcome,order_index,lesson_type,xp_reward,pass_threshold,total_exercises,estimated_minutes,prerequisites,content,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
              )
              .bind(
                crypto.randomUUID(),
                unitId,
                String(lesson.title || "Lesson " + (li + 1)),
                lesson.description || null,
                lesson.outcome || null,
                Number(lesson.order_index == null ? li : lesson.order_index),
                lesson.lesson_type || "lesson",
                Number(lesson.xp_reward == null ? 10 : lesson.xp_reward),
                Number(lesson.pass_threshold == null ? 80 : lesson.pass_threshold),
                0,
                Number(lesson.estimated_minutes == null ? 10 : lesson.estimated_minutes),
                JSON.stringify(Array.isArray(lesson.prerequisites) ? lesson.prerequisites : []),
                JSON.stringify({ exercises: [] }),
                timestamp,
                timestamp,
              )
              .run();
            lessonCount += 1;
          }
          await refreshUnitStats(db, unitId);
        }
        await refreshCourseStats(db, courseId);
      } catch (error) {
        errors.push(error instanceof Error ? error.message : String(error));
      }
    }

    return adminResponse({ courses: courseCount, units: unitCount, lessons: lessonCount, errors });
  }

  const match = path.match(/^courses\/([^/]+)$/);
  if (match) {
    const id = decodeURIComponent(match[1]);
    if (method === "PUT") {
      const body = await readBody(request);
      await updateByFields(
        db,
        "courses",
        id,
        body,
        ["title", "description", "language", "level", "tags", "thumbnail_url", "is_published"],
        {
          tags: (value) => JSON.stringify(Array.isArray(value) ? value : []),
          is_published: (value) => (value ? 1 : 0),
        },
      );
      const row = await db.prepare("SELECT * FROM courses WHERE id = ?").bind(id).first();
      return adminResponse(normalizeCourse(row));
    }
    if (method === "DELETE") {
      await db.prepare("DELETE FROM courses WHERE id = ?").bind(id).run();
      return adminResponse({ deleted: true });
    }
  }

  return null;
}

async function handleUnitsAdmin(context, path) {
  const db = requireDb(context);
  const request = context.request;
  const method = request.method.toUpperCase();
  const url = new URL(request.url);

  if (path === "units" && method === "GET") {
    const courseId = String(url.searchParams.get("course_id") || "").trim();
    const search = String(url.searchParams.get("search") || "").trim();
    const where = [];
    const params = [];
    if (courseId) {
      where.push("course_id = ?");
      params.push(courseId);
    }
    if (search) {
      where.push("LOWER(title) LIKE ?");
      params.push("%" + search.toLowerCase() + "%");
    }
    const whereSql = where.length ? " WHERE " + where.join(" AND ") : "";
    const rows = await db.prepare("SELECT * FROM units" + whereSql + " ORDER BY course_id, order_index, title").bind(...params).all();
    return adminResponse((rows.results || []).map(normalizeUnit));
  }

  if (path === "units" && method === "POST") {
    const body = await readBody(request);
    if (!body.course_id || !String(body.title || "").trim()) return adminError("course_id and title are required", 422);
    const id = crypto.randomUUID();
    const timestamp = nowIso();
    await db
      .prepare(
        "INSERT INTO units(id,course_id,title,description,order_index,background_color,icon_url,total_lessons,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
      )
      .bind(
        id,
        body.course_id,
        String(body.title).trim(),
        body.description || null,
        Number(body.order_index || 0),
        body.background_color || null,
        body.icon_url || null,
        0,
        timestamp,
        timestamp,
      )
      .run();
    await refreshCourseStats(db, body.course_id);
    const row = await db.prepare("SELECT * FROM units WHERE id = ?").bind(id).first();
    return adminResponse(normalizeUnit(row), 201);
  }

  const match = path.match(/^units\/([^/]+)$/);
  if (match) {
    const id = decodeURIComponent(match[1]);
    const before = await db.prepare("SELECT course_id FROM units WHERE id = ?").bind(id).first();
    if (method === "PUT") {
      const body = await readBody(request);
      await updateByFields(
        db,
        "units",
        id,
        body,
        ["course_id", "title", "description", "order_index", "background_color", "icon_url"],
      );
      const after = await db.prepare("SELECT * FROM units WHERE id = ?").bind(id).first();
      if (before && before.course_id) await refreshCourseStats(db, before.course_id);
      if (after && after.course_id) await refreshCourseStats(db, after.course_id);
      return adminResponse(normalizeUnit(after));
    }
    if (method === "DELETE") {
      await db.prepare("DELETE FROM units WHERE id = ?").bind(id).run();
      if (before && before.course_id) await refreshCourseStats(db, before.course_id);
      return adminResponse({ deleted: true });
    }
  }

  return null;
}

async function handleLessonsAdmin(context, path) {
  const db = requireDb(context);
  const request = context.request;
  const method = request.method.toUpperCase();
  const url = new URL(request.url);

  if (path === "lessons" && method === "GET") {
    const unitId = String(url.searchParams.get("unit_id") || "").trim();
    const courseId = String(url.searchParams.get("course_id") || "").trim();
    let sql = "SELECT l.* FROM lessons l";
    const where = [];
    const params = [];
    if (courseId) {
      sql += " JOIN units u ON l.unit_id = u.id";
      where.push("u.course_id = ?");
      params.push(courseId);
    }
    if (unitId) {
      where.push("l.unit_id = ?");
      params.push(unitId);
    }
    if (where.length) sql += " WHERE " + where.join(" AND ");
    sql += " ORDER BY l.unit_id, l.order_index, l.title";
    const rows = await db.prepare(sql).bind(...params).all();
    return adminResponse((rows.results || []).map(normalizeLesson));
  }

  if (path === "lessons" && method === "POST") {
    const body = await readBody(request);
    if (!body.unit_id || !String(body.title || "").trim()) return adminError("unit_id and title are required", 422);
    const id = crypto.randomUUID();
    const timestamp = nowIso();
    await db
      .prepare(
        "INSERT INTO lessons(id,unit_id,title,description,outcome,order_index,lesson_type,xp_reward,pass_threshold,total_exercises,estimated_minutes,prerequisites,content,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
      )
      .bind(
        id,
        body.unit_id,
        String(body.title).trim(),
        body.description || null,
        body.outcome || null,
        Number(body.order_index || 0),
        body.lesson_type || "lesson",
        Number(body.xp_reward == null ? 10 : body.xp_reward),
        Number(body.pass_threshold == null ? 80 : body.pass_threshold),
        0,
        Number(body.estimated_minutes == null ? 10 : body.estimated_minutes),
        JSON.stringify(Array.isArray(body.prerequisites) ? body.prerequisites : []),
        JSON.stringify({ exercises: [] }),
        timestamp,
        timestamp,
      )
      .run();
    await refreshUnitStats(db, body.unit_id);
    const row = await db.prepare("SELECT * FROM lessons WHERE id = ?").bind(id).first();
    return adminResponse(normalizeLesson(row), 201);
  }

  const contentMatch = path.match(/^lessons\/([^/]+)\/content$/);
  if (contentMatch && method === "PUT") {
    const id = decodeURIComponent(contentMatch[1]);
    const body = await readBody(request);
    const row = await db.prepare("SELECT unit_id FROM lessons WHERE id = ?").bind(id).first();
    if (!row) return adminError("Lesson not found", 404);
    const content = body.content && typeof body.content === "object" ? body.content : { exercises: [] };
    const exercises = Array.isArray(content.exercises) ? content.exercises : [];
    await db
      .prepare("UPDATE lessons SET content=?, total_exercises=?, estimated_minutes=?, updated_at=? WHERE id=?")
      .bind(
        JSON.stringify({ ...content, exercises }),
        Number(body.total_exercises == null ? exercises.length : body.total_exercises),
        Number(body.estimated_minutes == null ? 10 : body.estimated_minutes),
        nowIso(),
        id,
      )
      .run();
    await refreshUnitStats(db, row.unit_id);
    const updated = await db.prepare("SELECT * FROM lessons WHERE id = ?").bind(id).first();
    return adminResponse(normalizeLessonDetail(updated));
  }

  const match = path.match(/^lessons\/([^/]+)$/);
  if (match) {
    const id = decodeURIComponent(match[1]);
    const before = await db.prepare("SELECT unit_id FROM lessons WHERE id = ?").bind(id).first();
    if (method === "GET") {
      const row = await db.prepare("SELECT * FROM lessons WHERE id = ?").bind(id).first();
      return row ? adminResponse(normalizeLessonDetail(row)) : adminError("Lesson not found", 404);
    }
    if (method === "PUT") {
      const body = await readBody(request);
      await updateByFields(
        db,
        "lessons",
        id,
        body,
        ["unit_id", "title", "description", "outcome", "order_index", "lesson_type", "xp_reward", "pass_threshold", "estimated_minutes", "prerequisites"],
        { prerequisites: (value) => JSON.stringify(Array.isArray(value) ? value : []) },
      );
      const after = await db.prepare("SELECT * FROM lessons WHERE id = ?").bind(id).first();
      if (before && before.unit_id) await refreshUnitStats(db, before.unit_id);
      if (after && after.unit_id && (!before || after.unit_id !== before.unit_id)) await refreshUnitStats(db, after.unit_id);
      return adminResponse(normalizeLesson(after));
    }
    if (method === "DELETE") {
      await db.prepare("DELETE FROM lessons WHERE id = ?").bind(id).run();
      if (before && before.unit_id) await refreshUnitStats(db, before.unit_id);
      return adminResponse({ deleted: true });
    }
  }

  return null;
}

async function handleVocabularyAdmin(context, path) {
  const db = requireDb(context);
  const request = context.request;
  const method = request.method.toUpperCase();
  const url = new URL(request.url);

  if (path === "vocabulary" && method === "GET") {
    const limit = clampInt(url.searchParams.get("limit"), 1, 500, 100);
    const offset = clampInt(url.searchParams.get("offset"), 0, 1000000, 0);
    const rows = await db.prepare("SELECT * FROM vocabulary ORDER BY LOWER(word) ASC LIMIT ? OFFSET ?").bind(limit, offset).all();
    return adminResponse((rows.results || []).map(normalizeVocabulary));
  }

  if (path === "vocabulary" && method === "POST") {
    const body = await readBody(request);
    const source = { ...Object.fromEntries(url.searchParams.entries()), ...body };
    const word = String(source.word || "").trim();
    if (!word) return adminError("Word is required", 422);
    const id = crypto.randomUUID();
    const timestamp = nowIso();
    try {
      await db
        .prepare(
          "INSERT INTO vocabulary(id,word,definition,translation,part_of_speech,pronunciation,difficulty_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
        )
        .bind(
          id,
          word,
          source.definition || "",
          JSON.stringify({ vi: String(source.translation || "") }),
          source.part_of_speech || "noun",
          source.pronunciation || "",
          source.difficulty_level || "A1",
          timestamp,
          timestamp,
        )
        .run();
    } catch (_) {
      return adminError("This word already exists", 409);
    }
    const row = await db.prepare("SELECT * FROM vocabulary WHERE id = ?").bind(id).first();
    return adminResponse(normalizeVocabulary(row), 201);
  }

  if (path === "vocabulary/bulk-import" && method === "POST") {
    const form = await request.formData();
    const file = form.get("file");
    if (!file || typeof file.text !== "function") return adminError("CSV file is required", 422);
    const text = await file.text();
    const lines = text.split(/\r?\n/).filter((line) => line.trim());
    if (lines.length < 2) return adminError("CSV file is empty", 422);
    const headers = parseCsvLine(lines[0]).map((item) => item.trim().toLowerCase());
    let created = 0;
    let skipped = 0;
    const errors = [];

    for (let i = 1; i < lines.length && i <= 500; i += 1) {
      try {
        const values = parseCsvLine(lines[i]);
        const row = {};
        headers.forEach((header, index) => {
          row[header] = String(values[index] || "").trim();
        });
        if (!row.word) {
          skipped += 1;
          continue;
        }
        const id = crypto.randomUUID();
        const timestamp = nowIso();
        const result = await db
          .prepare(
            "INSERT OR IGNORE INTO vocabulary(id,word,definition,translation,part_of_speech,pronunciation,difficulty_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
          )
          .bind(
            id,
            row.word,
            row.definition || "",
            JSON.stringify({ vi: row.translation || "" }),
            row.part_of_speech || "noun",
            row.pronunciation || "",
            row.difficulty_level || "A1",
            timestamp,
            timestamp,
          )
          .run();
        if (Number(result.meta && result.meta.changes ? result.meta.changes : 0) > 0) created += 1;
        else skipped += 1;
      } catch (error) {
        errors.push("Row " + (i + 1) + ": " + (error instanceof Error ? error.message : String(error)));
      }
    }

    return adminResponse({ created, skipped, errors });
  }

  const match = path.match(/^vocabulary\/([^/]+)$/);
  if (match) {
    const id = decodeURIComponent(match[1]);
    if (method === "PUT") {
      const body = await readBody(request);
      const source = { ...Object.fromEntries(url.searchParams.entries()), ...body };
      if (Object.prototype.hasOwnProperty.call(source, "translation")) {
        source.translation = JSON.stringify({ vi: String(source.translation || "") });
      }
      await updateByFields(
        db,
        "vocabulary",
        id,
        source,
        ["word", "definition", "translation", "part_of_speech", "pronunciation", "difficulty_level"],
      );
      const row = await db.prepare("SELECT * FROM vocabulary WHERE id = ?").bind(id).first();
      return adminResponse(normalizeVocabulary(row));
    }
    if (method === "DELETE") {
      await db.prepare("DELETE FROM vocabulary WHERE id = ?").bind(id).run();
      return adminResponse({ deleted: true });
    }
  }

  return null;
}

async function handleTutorConfigAdmin(context, path) {
  const db = requireDb(context);
  const method = context.request.method.toUpperCase();
  if (path !== "ai-proxy/config") return null;
  if (method === "GET") {
    return Response.json(await loadTutorConfig(context), { headers: { "Cache-Control": "no-store" } });
  }
  if (method === "PUT") {
    const body = await readBody(context.request);
    return Response.json(await saveTutorConfig(db, body), { headers: { "Cache-Control": "no-store" } });
  }
  return adminError("Method not allowed", 405);
}

export async function handleAdminContent(context, path) {
  try {
    for (const handler of [handleCoursesAdmin, handleUnitsAdmin, handleLessonsAdmin, handleVocabularyAdmin, handleTutorConfigAdmin]) {
      const response = await handler(context, path);
      if (response) return response;
    }
    return adminError("Admin endpoint not found", 404);
  } catch (error) {
    return adminError(error instanceof Error ? error.message : String(error), Number(error && error.status) || 500);
  }
}

export async function handlePublicContent(context, rest) {
  const db = getDb(context);
  if (!db) return null;
  const request = context.request;
  const method = request.method.toUpperCase();
  const url = new URL(request.url);

  if (rest === "v1/courses" && method === "GET") {
    const page = clampInt(url.searchParams.get("page"), 1, 100000, 1);
    const pageSize = clampInt(url.searchParams.get("page_size"), 1, 100, 20);
    const language = String(url.searchParams.get("language") || "").trim();
    const level = String(url.searchParams.get("level") || "").trim();
    const where = ["is_published = 1"];
    const params = [];
    if (language) {
      where.push("language = ?");
      params.push(language);
    }
    if (level) {
      where.push("level = ?");
      params.push(level);
    }
    const whereSql = " WHERE " + where.join(" AND ");
    const count = await db.prepare("SELECT COUNT(*) AS total FROM courses" + whereSql).bind(...params).first();
    const total = Number(count && count.total ? count.total : 0);
    const rows = await db
      .prepare("SELECT * FROM courses" + whereSql + " ORDER BY level, title LIMIT ? OFFSET ?")
      .bind(...params, pageSize, (page - 1) * pageSize)
      .all();
    return publicPage((rows.results || []).map(normalizeCourse), page, pageSize, total);
  }

  if (rest === "v1/courses/enrolled" && method === "GET") {
    const page = clampInt(url.searchParams.get("page"), 1, 100000, 1);
    const pageSize = clampInt(url.searchParams.get("page_size"), 1, 100, 20);
    return publicPage([], page, pageSize, 0);
  }

  const enroll = rest.match(/^v1\/courses\/([^/]+)\/enroll$/);
  if (enroll && method === "POST") {
    return publicEnvelope({ message: "Guest web does not require enrollment." });
  }

  const course = rest.match(/^v1\/courses\/([^/]+)$/);
  if (course && method === "GET") {
    const id = decodeURIComponent(course[1]);
    const courseRow = await db.prepare("SELECT * FROM courses WHERE id = ? AND is_published = 1").bind(id).first();
    if (!courseRow) {
      return Response.json({ error: { code: "NOT_FOUND", message: "Course not found" } }, { status: 404 });
    }
    const unitRows = await db.prepare("SELECT * FROM units WHERE course_id = ? ORDER BY order_index, title").bind(id).all();
    const units = [];
    for (const row of unitRows.results || []) {
      const lessonRows = await db
        .prepare("SELECT id,title,order_index,lesson_type,xp_reward FROM lessons WHERE unit_id = ? ORDER BY order_index, title")
        .bind(row.id)
        .all();
      units.push({
        id: String(row.id),
        title: String(row.title || ""),
        description: row.description || null,
        order_index: Number(row.order_index || 0),
        background_color: row.background_color || null,
        icon_url: row.icon_url || null,
        lessons: (lessonRows.results || []).map((lesson) => ({
          id: String(lesson.id),
          title: String(lesson.title || ""),
          order_index: Number(lesson.order_index || 0),
          lesson_type: String(lesson.lesson_type || "lesson"),
          xp_reward: Number(lesson.xp_reward || 10),
          is_locked: false,
          is_completed: false,
        })),
      });
    }
    return publicEnvelope({
      ...normalizeCourse(courseRow),
      is_enrolled: false,
      user_progress: 0,
      units,
    });
  }

  if (rest === "v1/categories" && method === "GET") {
    const rows = await db
      .prepare(
        "SELECT je.value AS name, COUNT(DISTINCT c.id) AS course_count " +
          "FROM courses c, json_each(c.tags) je WHERE c.is_published = 1 " +
          "GROUP BY je.value ORDER BY course_count DESC, name ASC",
      )
      .all();
    return publicEnvelope(
      (rows.results || []).map((row) => {
        const name = String(row.name || "General");
        const slug = name.toLowerCase().replace(/\s+/g, "-");
        return {
          id: slug,
          name,
          slug,
          description: name + " learning track",
          icon: null,
          color: null,
          course_count: Number(row.course_count || 0),
        };
      }),
    );
  }

  const categoryCourses = rest.match(/^v1\/categories\/([^/]+)\/courses$/);
  if (categoryCourses && method === "GET") {
    const category = decodeURIComponent(categoryCourses[1]).toLowerCase().replace(/-/g, " ");
    const page = clampInt(url.searchParams.get("page"), 1, 100000, 1);
    const pageSize = clampInt(url.searchParams.get("page_size"), 1, 100, 20);
    const rows = await db
      .prepare(
        "SELECT DISTINCT c.* FROM courses c, json_each(c.tags) je " +
          "WHERE c.is_published = 1 AND LOWER(je.value) = ? ORDER BY c.level, c.title LIMIT ? OFFSET ?",
      )
      .bind(category, pageSize, (page - 1) * pageSize)
      .all();
    const count = await db
      .prepare(
        "SELECT COUNT(DISTINCT c.id) AS total FROM courses c, json_each(c.tags) je " +
          "WHERE c.is_published = 1 AND LOWER(je.value) = ?",
      )
      .bind(category)
      .first();
    return publicPage(
      (rows.results || []).map(normalizeCourse),
      page,
      pageSize,
      Number(count && count.total ? count.total : 0),
    );
  }

  return null;
}
