import React, { useState, useContext, useEffect } from 'react';
import { AuthContext } from '../contexts/AuthContext';
import '../styles/Home.css';

const DEFAULT_PROMPT = 'Обработай текст по заданным правилам. Текст: {text}. Слова для исключения (и однокоренные): {exc}. Ответь только результатом, без пояснений.';

function Home() {
  const { user, logout } = useContext(AuthContext);
  const [textInput, setTextInput] = useState('');
  const [excludeInput, setExcludeInput] = useState('');
  const [result, setResult] = useState('');
  const [resultsList, setResultsList] = useState([]);
  const [loading, setLoading] = useState(false);
  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [promptTemplate, setPromptTemplate] = useState(DEFAULT_PROMPT);
  const [requestCount, setRequestCount] = useState(1);
  const [settingsLoading, setSettingsLoading] = useState(true);

  const apiBase = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
    ? 'https://tg-text.ru/api'
    : '/api';

  useEffect(() => {
    loadHistory();
    loadSettings();
  }, []);

  const loadSettings = async () => {
    setSettingsLoading(true);
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        setPromptTemplate(DEFAULT_PROMPT);
        setRequestCount(1);
        return;
      }
      const response = await fetch(`${apiBase}/settings`, {
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (response.ok) {
        const data = await response.json();
        if (data.prompt_template != null) setPromptTemplate(data.prompt_template);
        if (data.request_count != null) setRequestCount(Math.max(1, parseInt(data.request_count, 10) || 1));
      }
    } catch (e) {
      console.error('Ошибка загрузки настроек:', e);
    } finally {
      setSettingsLoading(false);
    }
  };

  const saveSettings = async () => {
    const token = localStorage.getItem('token');
    if (!token) {
      setModalOpen(false);
      return;
    }
    try {
      await fetch(`${apiBase}/settings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          prompt_template: promptTemplate,
          request_count: requestCount,
        }),
      });
      setModalOpen(false);
    } catch (e) {
      console.error('Ошибка сохранения настроек:', e);
    }
  };

  const processText = async () => {
    if (!textInput.trim()) {
      alert('Пожалуйста, введите текст для обработки');
      return;
    }

    setLoading(true);
    setResult('');
    setResultsList([]);

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${apiBase}/process`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : '',
        },
        body: JSON.stringify({
          text: textInput,
          exclude_words: excludeInput,
          prompt_template: promptTemplate,
          request_count: requestCount,
        }),
      });

      if (!response.ok) {
        const err = await response.json();
        throw new Error(err.error || 'Ошибка обработки');
      }

      const data = await response.json();
      const list = Array.isArray(data.results) ? data.results : (data.result != null ? [data.result] : []);
      setResultsList(list);
      setResult(list.length === 1 ? list[0] : list.join('\n\n---\n\n'));
      loadHistory();
    } catch (error) {
      setResult('Ошибка: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const loadHistory = async () => {
    setHistoryLoading(true);
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        setHistory([]);
        return;
      }
      const response = await fetch(`${apiBase}/history`, {
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (response.ok) {
        const data = await response.json();
        setHistory(data.requests || []);
      }
    } catch (e) {
      console.error('Ошибка загрузки истории:', e);
    } finally {
      setHistoryLoading(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.ctrlKey && e.key === 'Enter') processText();
  };

  return (
    <div className="container">
      <div className="header">
        <div className="emoji">👋</div>
        <h1>Привет, я Никита</h1>
        <span className="build-id" title="Версия сборки">{import.meta.env.VITE_BUILD_ID || 'dev'}</span>
        <div className="user-info">
          <span>Пользователь: {user?.email}</span>
          <div>
            <button type="button" className="logout-btn" onClick={() => setModalOpen(true)} style={{ marginRight: 8, background: '#667eea' }}>
              Промпт и количество
            </button>
            <button onClick={logout} className="logout-btn">Выйти</button>
          </div>
        </div>
      </div>

      <div className="form-section">
        <div className="form-group">
          <label htmlFor="textInput">Введите текст для обработки:</label>
          <textarea
            id="textInput"
            value={textInput}
            onChange={(e) => setTextInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Введите текст здесь... (Ctrl+Enter для отправки)"
          />
        </div>

        <div className="form-group">
          <label htmlFor="excludeInput">Слова для исключения (через запятую):</label>
          <input
            type="text"
            id="excludeInput"
            value={excludeInput}
            onChange={(e) => setExcludeInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); processText(); } }}
            placeholder="например: привет, мир"
          />
          <div className="info-text">В промпте доступны переменные: {'{text}'} — текст, {'{exc}'} — слова исключения. Количество запросов: {requestCount}</div>
        </div>

        <button className="btn" onClick={processText} disabled={loading}>
          {loading ? 'Обработка...' : 'Обработать текст'}
        </button>

        {result && (
          <div className="result show">
            <div className="result-label">Результат{resultsList.length > 1 ? ` (${resultsList.length} запросов)` : ''}:</div>
            {resultsList.length > 1 ? (
              <div className="result-list">
                {resultsList.map((r, i) => (
                  <div key={i} className="result-item">
                    <div className="result-num">Результат {i + 1}</div>
                    <div className="result-text">{r}</div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="result-text">{result}</div>
            )}
          </div>
        )}
      </div>

      <div className="history-section">
        <h2>История запросов (за последние 7 дней)</h2>
        <div className="history-container">
          {historyLoading ? (
            <div className="loading">Загрузка истории...</div>
          ) : history.length === 0 ? (
            <div className="no-history">История запросов пуста</div>
          ) : (
            <>
              <div className="history-info">Всего запросов: {history.length}</div>
              <table className="history-table">
                <thead>
                  <tr>
                    <th>№</th>
                    <th>Дата и время</th>
                    <th>Запрос</th>
                    <th>Исключено</th>
                    <th>Результат</th>
                  </tr>
                </thead>
                <tbody>
                  {history.map((request, index) => (
                    <tr key={request.id}>
                      <td className="history-number">#{history.length - index}</td>
                      <td className="history-date">{new Date(request.created_at).toLocaleString('ru-RU')}</td>
                      <td className="history-request">{request.request_text}</td>
                      <td className="history-exclude">{request.exclude_words || '-'}</td>
                      <td className="history-result">{request.result_text}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          )}
        </div>
      </div>

      {modalOpen && (
        <div className="modal-overlay" onClick={() => setModalOpen(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>Промпт и количество запросов</h3>
            <div className="form-group">
              <label>Промпт (используйте {'{text}'} и {'{exc}'})</label>
              <textarea
                value={promptTemplate}
                onChange={(e) => setPromptTemplate(e.target.value)}
                placeholder="Например: Обработай текст: {text}. Исключи: {exc}. Ответь только результатом."
              />
              <div className="prompt-hint">{'{text}'} — подставится ваш текст, {'{exc}'} — слова для исключения</div>
            </div>
            <div className="form-group">
              <label>Количество запросов подряд (1–10)</label>
              <input
                type="number"
                min={1}
                max={10}
                value={requestCount}
                onChange={(e) => setRequestCount(Math.max(1, Math.min(10, parseInt(e.target.value, 10) || 1)))}
              />
            </div>
            <div className="modal-actions">
              <button type="button" className="btn btn-secondary" onClick={() => setModalOpen(false)}>Отмена</button>
              <button type="button" className="btn" onClick={saveSettings}>Сохранить</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default Home;
