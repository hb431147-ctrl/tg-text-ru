import React, { createContext, useState, useEffect } from 'react';

export const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Проверяем, есть ли сохраненный токен
    const token = localStorage.getItem('token');
    const userData = localStorage.getItem('user');
    
    if (token && userData) {
      try {
        setUser(JSON.parse(userData));
      } catch (e) {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
      }
    }
    setLoading(false);
  }, []);

  const login = async (email, password) => {
    try {
      const apiUrl = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
        ? 'https://tg-text.ru/api/auth/login'
        : '/api/auth/login';

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      // Проверяем Content-Type ответа
      const contentType = response.headers.get('content-type');
      if (!contentType || !contentType.includes('application/json')) {
        const text = await response.text();
        console.error('Ожидался JSON, получен:', contentType, text.substring(0, 200));
        throw new Error(`Сервер вернул неверный формат ответа. Статус: ${response.status}`);
      }

      if (!response.ok) {
        const error = await response.json().catch(() => ({ error: `Ошибка ${response.status}: ${response.statusText}` }));
        throw new Error(error.error || 'Ошибка авторизации');
      }

      const data = await response.json();
      const userData = { email: data.user.email, id: data.user.id };
      
      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(userData));
      setUser(userData);
      
      return { success: true };
    } catch (error) {
      console.error('Ошибка авторизации:', error);
      return { success: false, error: error.message };
    }
  };

  const register = async (email, password, name) => {
    try {
      const apiUrl = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
        ? 'https://tg-text.ru/api/auth/register'
        : '/api/auth/register';

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password, name }),
      });

      // Проверяем Content-Type ответа
      const contentType = response.headers.get('content-type');
      if (!contentType || !contentType.includes('application/json')) {
        const text = await response.text();
        console.error('Ожидался JSON, получен:', contentType, text.substring(0, 200));
        throw new Error(`Сервер вернул неверный формат ответа. Статус: ${response.status}`);
      }

      if (!response.ok) {
        const error = await response.json().catch(() => ({ error: `Ошибка ${response.status}: ${response.statusText}` }));
        throw new Error(error.error || 'Ошибка регистрации');
      }

      const data = await response.json();
      const userData = { email: data.user.email, id: data.user.id };
      
      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(userData));
      setUser(userData);
      
      return { success: true };
    } catch (error) {
      console.error('Ошибка регистрации:', error);
      return { success: false, error: error.message };
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, register, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
};

