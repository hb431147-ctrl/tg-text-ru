import React, { useState, useContext, useEffect } from 'react';
import { AuthContext } from '../contexts/AuthContext';
import '../styles/Home.css';

function Home() {
  const { user, logout } = useContext(AuthContext);
  const [textInput, setTextInput] = useState('');
  const [excludeInput, setExcludeInput] = useState('');
  const [result, setResult] = useState('');
  const [loading, setLoading] = useState(false);
  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(true);

  useEffect(() => {
    loadHistory();
  }, []);

  const processText = async () => {
    if (!textInput.trim()) {
      alert('Пожалуйста, введите текст для обработки');
      return;
    }

    setLoading(true);
    setResult('');

    try {
      const apiUrl = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
        ? 'https://tg-text.ru/api/process'
        : '/api/process';

      const token = localStorage.getItem('token');
      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : '',
        },
        body: JSON.stringify({
          text: textInput,
          exclude_words: excludeInput,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Ошибка обработки');
      }

      const data = await response.json();
      setResult(data.result || 'Результат пуст');
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
      const apiUrl = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
        ? 'https://tg-text.ru/api/history'
        : '/api/history';

      const token = localStorage.getItem('token');
      const response = await fetch(apiUrl, {
        headers: {
          'Authorization': token ? `Bearer ${token}` : '',
        },
      });

      if (response.ok) {
        const data = await response.json();
        setHistory(data.requests || []);
      }
    } catch (error) {
      console.error('Ошибка загрузки истории:', error);
    } finally {
      setHistoryLoading(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.ctrlKey && e.key === 'Enter') {
      processText();
    }
  };

  return (
    <div className="container">
      <div className="header">
        <div className="emoji">👋</div>
        <h1>Привет, я Никита</h1>
        <div className="user-info">
          <span>Пользователь: {user?.email}</span>
          <button onClick={logout} className="logout-btn">Выйти</button>
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
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                processText();
              }
            }}
            placeholder="например: привет, мир"
          />
          <div className="info-text">Будут исключены указанные слова и однокоренные им</div>
        </div>

        <button
          className="btn"
          onClick={processText}
          disabled={loading}
        >
          {loading ? 'Обработка...' : 'Обработать текст'}
        </button>

        {result && (
          <div className="result show">
            <div className="result-label">Результат:</div>
            <div className="result-text">{result}</div>
          </div>
        )}
      </div>

      <div className="history-section">
        <h2>История запросов</h2>
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
                      <td className="history-date">
                        {new Date(request.created_at).toLocaleString('ru-RU')}
                      </td>
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
    </div>
  );
}

export default Home;

