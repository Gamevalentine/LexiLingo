function nowIso() {
  return new Date().toISOString();
}

function json(data, status = 200) {
  return Response.json(
    { data, meta: { request_id: crypto.randomUUID(), timestamp: nowIso() } },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}

function error(message, status = 400, code = "LEARNING_ERROR") {
  return Response.json(
    { error: { code, message } },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}

function getDb(context) {
  return context.env.CONTENT_DB || null;
}

function parseJson(value, fallback) {
  if (value == null || value === "") return fallback;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

async function readJson(request) {
  try {
    return await request.json();
  } catch (_) {
    return {};
  }
}

function normalizeText(value) {
  return String(value ?? "")
    .toLowerCase()
    .trim()
    .replace(/[’‘]/g, "'")
    .replace(/\s+/g, " ")
    .replace(/[.!?]+$/g, "");
}

function isCorrectAnswer(exercise, userAnswer) {
  const correct = normalizeText(exercise.correct_answer);
  const answer = normalizeText(userAnswer);
  if (!correct) return false;
  if (answer === correct) return true;

  const type = String(exercise.type || "").toLowerCase();
  if (type === "fill_blank" || type === "fill_in_blank") {
    const compact = (v) => v.replace(/[^a-z0-9'\s]/g, "").replace(/\s+/g, " ").trim();
    return compact(answer) === compact(correct);
  }

  if (type === "translate" || type === "translation") {
    const alternatives = Array.isArray(exercise.accepted_answers)
      ? exercise.accepted_answers
      : [];
    return alternatives.some((item) => normalizeText(item) === answer);
  }

  return false;
}

async function findNextLesson(db, lessonId) {
  const row = await db
    .prepare(
      "SELECT l.id, u.course_id, u.order_index AS unit_order, l.order_index AS lesson_order " +
        "FROM lessons l JOIN units u ON l.unit_id=u.id WHERE l.id=?",
    )
    .bind(lessonId)
    .first();
  if (!row) return null;

  const next = await db
    .prepare(
      "SELECT l.id FROM lessons l JOIN units u ON l.unit_id=u.id " +
        "WHERE u.course_id=? AND (u.order_index>? OR (u.order_index=? AND l.order_index>?)) " +
        "ORDER BY u.order_index, l.order_index LIMIT 1",
    )
    .bind(row.course_id, row.unit_order, row.unit_order, row.lesson_order)
    .first();
  return next ? String(next.id) : null;
}

async function startLesson(context, lessonId) {
  const db = getDb(context);
  if (!db) return error("CONTENT_DB binding is unavailable", 503, "DB_UNAVAILABLE");

  const lesson = await db.prepare("SELECT id,total_exercises FROM lessons WHERE id=?").bind(lessonId).first();
  if (!lesson) return error("Lesson not found", 404, "NOT_FOUND");

  const attemptId = crypto.randomUUID();
  const startedAt = nowIso();
  await db
    .prepare(
      "INSERT INTO learning_attempts(id,lesson_id,started_at,answered_count,correct_count,xp_earned,hints_used,completed_at) " +
        "VALUES(?,?,?,?,?,?,?,NULL)",
    )
    .bind(attemptId, lessonId, startedAt, 0, 0, 0, 0)
    .run();

  return json({
    attempt_id: attemptId,
    lesson_id: lessonId,
    started_at: startedAt,
    total_questions: Number(lesson.total_exercises || 0),
    lives_remaining: 3,
    hints_available: 3,
  });
}

async function lessonContent(context, lessonId) {
  const db = getDb(context);
  if (!db) return error("CONTENT_DB binding is unavailable", 503, "DB_UNAVAILABLE");
  const row = await db.prepare("SELECT * FROM lessons WHERE id=?").bind(lessonId).first();
  if (!row) return error("Lesson not found", 404, "NOT_FOUND");

  const content = parseJson(row.content, { exercises: [] });
  return json({
    id: String(row.id),
    title: String(row.title || ""),
    description: row.description || null,
    outcome: row.outcome || null,
    lesson_type: String(row.lesson_type || "lesson"),
    order_index: Number(row.order_index || 0),
    xp_reward: Number(row.xp_reward || 10),
    pass_threshold: Number(row.pass_threshold || 80),
    estimated_minutes: Number(row.estimated_minutes || 10),
    total_exercises: Array.isArray(content.exercises) ? content.exercises.length : 0,
    intro: content.intro || null,
    source_basis: content.source_basis || null,
    exercises: Array.isArray(content.exercises) ? content.exercises : [],
  });
}

async function submitAnswer(context, attemptId) {
  const db = getDb(context);
  if (!db) return error("CONTENT_DB binding is unavailable", 503, "DB_UNAVAILABLE");
  const body = await readJson(context.request);
  const attempt = await db.prepare("SELECT * FROM learning_attempts WHERE id=?").bind(attemptId).first();
  if (!attempt) return error("Attempt not found", 404, "NOT_FOUND");

  const lesson = await db.prepare("SELECT content FROM lessons WHERE id=?").bind(attempt.lesson_id).first();
  if (!lesson) return error("Lesson not found", 404, "NOT_FOUND");
  const content = parseJson(lesson.content, { exercises: [] });
  const exercise = (content.exercises || []).find((item) => String(item.id) === String(body.question_id));
  if (!exercise) return error("Question not found", 404, "QUESTION_NOT_FOUND");

  const correct = isCorrectAnswer(exercise, body.user_answer);
  const answeredCount = Number(attempt.answered_count || 0) + 1;
  const correctCount = Number(attempt.correct_count || 0) + (correct ? 1 : 0);
  const xpEarned = Number(attempt.xp_earned || 0) + (correct ? Number(exercise.points || 10) : 0);
  const hintsUsed = Number(attempt.hints_used || 0) + (body.hint_used ? 1 : 0);

  await db
    .prepare("UPDATE learning_attempts SET answered_count=?,correct_count=?,xp_earned=?,hints_used=? WHERE id=?")
    .bind(answeredCount, correctCount, xpEarned, hintsUsed, attemptId)
    .run();

  const livesRemaining = Math.max(0, 3 - (answeredCount - correctCount));
  const hintsRemaining = Math.max(0, 3 - hintsUsed);
  const currentScore = answeredCount ? (correctCount / answeredCount) * 100 : 0;

  return json({
    question_attempt_id: crypto.randomUUID(),
    is_correct: correct,
    correct_answer: String(exercise.correct_answer ?? ""),
    explanation: exercise.explanation || null,
    xp_earned: correct ? Number(exercise.points || 10) : 0,
    lives_remaining: livesRemaining,
    hints_remaining: hintsRemaining,
    current_score: currentScore,
  });
}

async function completeAttempt(context, attemptId) {
  const db = getDb(context);
  if (!db) return error("CONTENT_DB binding is unavailable", 503, "DB_UNAVAILABLE");
  const attempt = await db.prepare("SELECT * FROM learning_attempts WHERE id=?").bind(attemptId).first();
  if (!attempt) return error("Attempt not found", 404, "NOT_FOUND");
  const lesson = await db.prepare("SELECT pass_threshold FROM lessons WHERE id=?").bind(attempt.lesson_id).first();
  if (!lesson) return error("Lesson not found", 404, "NOT_FOUND");

  const total = Number(attempt.answered_count || 0);
  const correct = Number(attempt.correct_count || 0);
  const wrong = Math.max(0, total - correct);
  const score = total ? (correct / total) * 100 : 0;
  const passed = score >= Number(lesson.pass_threshold || 80);
  const stars = score >= 95 ? 3 : score >= 85 ? 2 : passed ? 1 : 0;
  const completedAt = nowIso();
  const started = Date.parse(String(attempt.started_at || completedAt));
  const seconds = Math.max(0, Math.round((Date.now() - (Number.isFinite(started) ? started : Date.now())) / 1000));
  const nextLesson = await findNextLesson(db, String(attempt.lesson_id));

  await db.prepare("UPDATE learning_attempts SET completed_at=? WHERE id=?").bind(completedAt, attemptId).run();

  const previous = await db.prepare("SELECT * FROM lesson_progress WHERE lesson_id=?").bind(attempt.lesson_id).first();
  const best = Math.max(Number(previous?.best_score || 0), score);
  const attempts = Number(previous?.attempts_count || 0) + 1;
  const completed = Boolean(previous?.is_completed) || passed;
  const bestStars = Math.max(Number(previous?.stars_earned || 0), stars);

  await db
    .prepare(
      "INSERT INTO lesson_progress(lesson_id,best_score,is_completed,attempts_count,stars_earned,updated_at) " +
        "VALUES(?,?,?,?,?,?) ON CONFLICT(lesson_id) DO UPDATE SET " +
        "best_score=excluded.best_score,is_completed=excluded.is_completed,attempts_count=excluded.attempts_count," +
        "stars_earned=excluded.stars_earned,updated_at=excluded.updated_at",
    )
    .bind(attempt.lesson_id, best, completed ? 1 : 0, attempts, bestStars, completedAt)
    .run();

  return json({
    attempt_id: attemptId,
    passed,
    final_score: score,
    total_xp_earned: Number(attempt.xp_earned || 0),
    time_spent_seconds: seconds,
    accuracy: score,
    stars_earned: stars,
    next_lesson_unlocked: passed ? nextLesson : null,
    achievements_unlocked: [],
    total_questions: total,
    correct_answers: correct,
    wrong_answers: wrong,
    hints_used: Number(attempt.hints_used || 0),
  });
}

async function roadmap(context, courseId) {
  const db = getDb(context);
  if (!db) return error("CONTENT_DB binding is unavailable", 503, "DB_UNAVAILABLE");
  const course = await db.prepare("SELECT * FROM courses WHERE id=? AND is_published=1").bind(courseId).first();
  if (!course) return error("Course not found", 404, "NOT_FOUND");

  const unitsRows = await db.prepare("SELECT * FROM units WHERE course_id=? ORDER BY order_index").bind(courseId).all();
  const units = [];
  let totalLessons = 0;
  let completedLessons = 0;
  let totalXpEarned = 0;
  let currentAssigned = false;

  for (let ui = 0; ui < (unitsRows.results || []).length; ui += 1) {
    const unit = unitsRows.results[ui];
    const lessonRows = await db
      .prepare(
        "SELECT l.*,p.best_score,p.is_completed,p.attempts_count,p.stars_earned " +
          "FROM lessons l LEFT JOIN lesson_progress p ON p.lesson_id=l.id " +
          "WHERE l.unit_id=? ORDER BY l.order_index",
      )
      .bind(unit.id)
      .all();

    const lessons = [];
    let unitCompleted = 0;
    for (let li = 0; li < (lessonRows.results || []).length; li += 1) {
      const lesson = lessonRows.results[li];
      const isCompleted = Boolean(lesson.is_completed);
      if (isCompleted) {
        unitCompleted += 1;
        completedLessons += 1;
      }
      totalLessons += 1;
      const isCurrent = !currentAssigned && !isCompleted;
      if (isCurrent) currentAssigned = true;
      lessons.push({
        lesson_id: String(lesson.id),
        lesson_number: li + 1,
        title: String(lesson.title || ""),
        description: lesson.description || null,
        is_locked: false,
        is_current: isCurrent,
        is_completed: isCompleted,
        best_score: lesson.best_score == null ? null : Number(lesson.best_score),
        stars_earned: Number(lesson.stars_earned || 0),
        attempts_count: Number(lesson.attempts_count || 0),
        completion_percentage: isCompleted ? 100 : 0,
        icon_url: null,
        background_color: "#4CAF50",
      });
    }

    units.push({
      unit_id: String(unit.id),
      unit_number: ui + 1,
      title: String(unit.title || ""),
      description: unit.description || null,
      total_lessons: lessons.length,
      completed_lessons: unitCompleted,
      completion_percentage: lessons.length ? (unitCompleted / lessons.length) * 100 : 0,
      is_current: lessons.some((item) => item.is_current),
      lessons,
      icon_url: unit.icon_url || null,
      background_color: unit.background_color || "#2196F3",
    });
  }

  const attempts = await db
    .prepare(
      "SELECT COALESCE(SUM(a.xp_earned),0) AS xp FROM learning_attempts a " +
        "JOIN lessons l ON a.lesson_id=l.id JOIN units u ON l.unit_id=u.id WHERE u.course_id=? AND a.completed_at IS NOT NULL",
    )
    .bind(courseId)
    .first();
  totalXpEarned = Number(attempts?.xp || 0);

  return json({
    course_id: String(course.id),
    course_title: String(course.title || ""),
    level: String(course.level || "A1"),
    total_units: units.length,
    completed_units: units.filter((u) => u.total_lessons > 0 && u.completed_lessons === u.total_lessons).length,
    total_lessons: totalLessons,
    completed_lessons: completedLessons,
    completion_percentage: totalLessons ? (completedLessons / totalLessons) * 100 : 0,
    total_xp_earned: totalXpEarned,
    current_streak: 0,
    units,
  });
}

export async function handleLearning(context, rest) {
  const method = context.request.method.toUpperCase();

  let match = rest.match(/^v1\/learning\/lessons\/([^/]+)\/start$/);
  if (match && method === "POST") return startLesson(context, decodeURIComponent(match[1]));

  match = rest.match(/^v1\/learning\/lessons\/([^/]+)\/content$/);
  if (match && method === "GET") return lessonContent(context, decodeURIComponent(match[1]));

  match = rest.match(/^v1\/learning\/attempts\/([^/]+)\/answer$/);
  if (match && method === "POST") return submitAnswer(context, decodeURIComponent(match[1]));

  match = rest.match(/^v1\/learning\/attempts\/([^/]+)\/complete$/);
  if (match && method === "POST") return completeAttempt(context, decodeURIComponent(match[1]));

  match = rest.match(/^v1\/learning\/courses\/([^/]+)\/roadmap$/);
  if (match && method === "GET") return roadmap(context, decodeURIComponent(match[1]));

  return null;
}
