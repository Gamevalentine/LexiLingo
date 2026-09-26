import React, { useEffect, useState } from "react";
import { Bot, MessageSquareText, Save, SlidersHorizontal } from "lucide-react";
import { SectionHeader } from "../components/SectionHeader";
import { authStore } from "../lib/auth";
import { getAiConfig, updateAiConfig } from "../lib/healthApi";

type TutorConfig = {
  model_name: string;
  temperature: number;
  max_tokens: number;
  top_p: number;
  chat_memory_turns: number;
  enable_voice: boolean;
  enable_grammar: boolean;
  enable_topic: boolean;
  system_prompt: string;
};

const fallback: TutorConfig = {
  model_name: "@cf/meta/llama-3.1-8b-instruct-fast",
  temperature: 0.7,
  max_tokens: 1200,
  top_p: 0.9,
  chat_memory_turns: 12,
  enable_voice: true,
  enable_grammar: true,
  enable_topic: true,
  system_prompt: "",
};

export const AiChatSettingsPage = () => {
  const [config, setConfig] = useState<TutorConfig>(fallback);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await getAiConfig(authStore.accessToken ?? undefined);
      const body = await response.json();
      if (!response.ok) throw new Error(body?.error?.message || body?.message || "Không tải được cấu hình AI.");
      setConfig({ ...fallback, ...body });
    } catch (err: any) {
      setError(err?.message || "Không tải được cấu hình AI.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const save = async () => {
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      const response = await updateAiConfig(config, authStore.accessToken ?? undefined);
      const body = await response.json();
      if (!response.ok) throw new Error(body?.error?.message || body?.message || "Lưu thất bại.");
      setConfig({ ...fallback, ...body });
      setMessage("Đã lưu. Lexi sẽ dùng cấu hình mới cho các tin nhắn tiếp theo.");
    } catch (err: any) {
      setError(err?.message || "Lưu thất bại.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="loading">Đang tải cấu hình Lexi...</div>;

  return (
    <div className="stack">
      <div style={{ display: "flex", justifyContent: "space-between", gap: 16, alignItems: "flex-start", flexWrap: "wrap" }}>
        <SectionHeader
          title="Cấu hình Lexi AI"
          description="Thay đổi prompt và cách Lexi trả lời mà không cần sửa source code."
        />
        <button className="primary-button" onClick={save} disabled={saving}>
          <Save size={16} />
          {saving ? "Đang lưu..." : "Lưu cấu hình"}
        </button>
      </div>

      {error && <div className="form-error">{error}</div>}
      {message && (
        <div className="panel" style={{ padding: 14, background: "#ecfdf5", borderColor: "#a7f3d0", color: "#065f46" }}>
          {message}
        </div>
      )}

      <div className="panel">
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16 }}>
          <MessageSquareText size={20} />
          <h3 style={{ margin: 0 }}>System prompt</h3>
        </div>
        <textarea
          rows={14}
          value={config.system_prompt}
          onChange={(e) => setConfig({ ...config, system_prompt: e.target.value })}
          style={{ width: "100%", resize: "vertical", fontFamily: "inherit", lineHeight: 1.5 }}
          placeholder="Mô tả cách Lexi phải dạy và phản hồi..."
        />
        <div className="table-meta" style={{ marginTop: 8 }}>
          Prompt này được nạp trực tiếp bởi Cloudflare Workers AI ở mỗi lượt chat.
        </div>
      </div>

      <div className="grid-2">
        <div className="panel">
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16 }}>
            <Bot size={20} />
            <h3 style={{ margin: 0 }}>Model</h3>
          </div>
          <label>
            Cloudflare Workers AI model
            <select
              value={config.model_name}
              onChange={(e) => setConfig({ ...config, model_name: e.target.value })}
            >
              <option value="@cf/meta/llama-3.1-8b-instruct-fast">Llama 3.1 8B Instruct Fast</option>
            </select>
          </label>
          <p className="table-meta" style={{ marginTop: 10 }}>
            Giai đoạn này chỉ bật model đang được hệ thống kiểm thử ổn định.
          </p>
        </div>

        <div className="panel">
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16 }}>
            <SlidersHorizontal size={20} />
            <h3 style={{ margin: 0 }}>Cách trả lời</h3>
          </div>

          <label>
            Temperature: {config.temperature.toFixed(1)}
            <input
              type="range"
              min={0}
              max={1.5}
              step={0.1}
              value={config.temperature}
              onChange={(e) => setConfig({ ...config, temperature: Number(e.target.value) })}
            />
          </label>

          <label>
            Max tokens
            <input
              type="number"
              min={256}
              max={4096}
              value={config.max_tokens}
              onChange={(e) => setConfig({ ...config, max_tokens: Number(e.target.value) })}
            />
          </label>

          <label>
            Số lượt hội thoại được nhớ
            <input
              type="number"
              min={0}
              max={30}
              value={config.chat_memory_turns}
              onChange={(e) => setConfig({ ...config, chat_memory_turns: Number(e.target.value) })}
            />
          </label>
        </div>
      </div>

      <div className="panel">
        <h3 style={{ marginTop: 0 }}>Tính năng</h3>
        <div style={{ display: "flex", gap: 20, flexWrap: "wrap" }}>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={config.enable_voice}
              onChange={(e) => setConfig({ ...config, enable_voice: e.target.checked })}
            />
            Voice
          </label>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={config.enable_grammar}
              onChange={(e) => setConfig({ ...config, enable_grammar: e.target.checked })}
            />
            Sửa ngữ pháp
          </label>
          <label className="checkbox">
            <input
              type="checkbox"
              checked={config.enable_topic}
              onChange={(e) => setConfig({ ...config, enable_topic: e.target.checked })}
            />
            Hội thoại theo chủ đề
          </label>
        </div>
      </div>
    </div>
  );
};
