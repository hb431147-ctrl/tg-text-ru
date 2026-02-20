#!/usr/bin/env node
/**
 * API сервер для обработки текста (Node.js)
 */

const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production-2024';

// Настройки подключения к MySQL
const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'tg_text_user',
    password: process.env.DB_PASSWORD || 'tg_text_password_2024',
    database: process.env.DB_NAME || 'tg_text_db',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
};

// Создание пула подключений
let dbPool;
try {
    dbPool = mysql.createPool(dbConfig);
    console.log('Подключение к MySQL настроено');
} catch (error) {
    console.error('Ошибка создания пула подключений MySQL:', error);
    dbPool = null;
}

// Функция для получения IP адреса пользователя
function getUserIP(req) {
    return req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
           req.headers['x-real-ip'] ||
           req.connection?.remoteAddress ||
           req.socket?.remoteAddress ||
           'unknown';
}

// Middleware для логирования
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
    if (req.method === 'POST' && req.path.startsWith('/api')) {
        console.log('Headers:', JSON.stringify(req.headers));
        console.log('Body:', req.body);
        console.log('Content-Type:', req.get('Content-Type'));
    }
    next();
});

// CORS
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false
}));

// Обработка OPTIONS запросов
app.options('*', cors());

// Парсинг JSON
app.use(express.json({ 
    limit: '10mb',
    strict: false
}));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Обработка ошибок парсинга JSON
app.use((err, req, res, next) => {
    if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
        console.error('Ошибка парсинга JSON:', err.message);
        console.error('URL:', req.url);
        console.error('Method:', req.method);
        console.error('Content-Type:', req.get('Content-Type'));
        console.error('Body preview:', req.body ? JSON.stringify(req.body).substring(0, 200) : 'empty');
        return res.status(400).json({ error: 'Неверный формат JSON: ' + err.message });
    }
    next();
});

/**
 * Middleware для проверки JWT токена
 */
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
        return res.status(401).json({ error: 'Токен не предоставлен' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Недействительный токен' });
        }
        req.user = user;
        next();
    });
}

/**
 * Опциональная аутентификация (для обратной совместимости)
 */
function optionalAuth(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
        jwt.verify(token, JWT_SECRET, (err, user) => {
            if (!err) {
                req.user = user;
            }
        });
    }
    next();
}

/**
 * Получить корень слова (упрощенный алгоритм)
 */
function getWordRoot(word) {
    word = word.toLowerCase().trim();
    if (word.length <= 3) return word;
    
    // Типичные окончания русского языка
    const endings = ['ый', 'ая', 'ое', 'ые', 'ой', 'ей', 'ом', 'ем', 'ую', 'ую',
                     'ов', 'ев', 'ин', 'ын', 'ых', 'их', 'ам', 'ям', 'ами', 'ями',
                     'ах', 'ях', 'и', 'ы', 'а', 'о', 'е', 'у', 'ю', 'ь', 'ъ'];
    
    // Пробуем убрать окончания разной длины
    for (let length = 3; length >= 1; length--) {
        if (word.length > length) {
            const ending = word.slice(-length);
            if (endings.includes(ending)) {
                return word.slice(0, -length);
            }
        }
    }
    
    // Если окончание не найдено, возвращаем первые 4-5 символов как корень
    return word.slice(0, Math.max(4, word.length - 2));
}

/**
 * Проверка, являются ли слова однокоренными
 */
function areRelatedWords(word1, word2) {
    const root1 = getWordRoot(word1);
    const root2 = getWordRoot(word2);
    
    // Сравниваем корни
    if (root1 === root2) return true;
    
    // Проверяем, содержит ли один корень другой
    if (root1.length >= 4 && root2.length >= 4) {
        if (root1.includes(root2) || root2.includes(root1)) {
            return true;
        }
    }
    
    // Проверяем общий префикс длиной 4+ символов
    let commonPrefix = '';
    const minLen = Math.min(root1.length, root2.length);
    for (let i = 0; i < minLen; i++) {
        if (root1[i] === root2[i]) {
            commonPrefix += root1[i];
        } else {
            break;
        }
    }
    
    return commonPrefix.length >= 4;
}

/**
 * Перемешивание массива (алгоритм Фишера-Йетса)
 */
function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

/**
 * Основная функция обработки текста
 */
function processText(text, excludeWordsStr) {
    if (!text || !text.trim()) {
        return { error: 'Текст не может быть пустым' };
    }
    
    // Разбиваем текст на слова
    const words = text.match(/\S+/g) || [];
    
    if (words.length === 0) {
        return { error: 'Текст не содержит слов' };
    }
    
    // Получаем список слов для исключения
    const excludeWords = excludeWordsStr
        ? excludeWordsStr.split(',').map(w => w.trim().toLowerCase()).filter(w => w.length > 0)
        : [];
    
    // Фильтруем слова: исключаем указанные и однокоренные
    const filteredWords = words.filter(word => {
        const wordLower = word.toLowerCase();
        
        // Проверяем точное совпадение
        if (excludeWords.includes(wordLower)) {
            return false;
        }
        
        // Проверяем однокоренные слова
        for (const excludeWord of excludeWords) {
            if (areRelatedWords(wordLower, excludeWord)) {
                return false;
            }
        }
        
        return true;
    });
    
    if (filteredWords.length === 0) {
        return { result: 'Все слова были исключены. Результат пуст.' };
    }
    
    // Перемешиваем оставшиеся слова
    const shuffledWords = shuffleArray(filteredWords);
    
    // Формируем результат, сохраняя структуру текста
    const resultParts = [];
    let wordIndex = 0;
    
    // Разбиваем исходный текст на сегменты (слова и пробелы)
    const segments = text.split(/(\s+)/);
    
    for (const segment of segments) {
        if (segment.trim() && !/^\s+$/.test(segment)) {
            // Это слово
            if (wordIndex < shuffledWords.length) {
                resultParts.push(shuffledWords[wordIndex]);
                wordIndex++;
            }
        } else {
            // Это пробелы или знаки препинания
            resultParts.push(segment);
        }
    }
    
    // Если остались слова после обработки
    while (wordIndex < shuffledWords.length) {
        resultParts.push((resultParts.length > 0 ? ' ' : '') + shuffledWords[wordIndex]);
        wordIndex++;
    }
    
    const result = resultParts.join('');
    
    return { result: result };
}

/**
 * Обработка OPTIONS для CORS preflight
 */
app.options('/api/auth/register', cors());
app.options('/api/auth/login', cors());

/**
 * API endpoint для регистрации
 */
app.post('/api/auth/register', async (req, res) => {
    try {
        const { email, password, name } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email и пароль обязательны' });
        }

        if (password.length < 6) {
            return res.status(400).json({ error: 'Пароль должен содержать минимум 6 символов' });
        }

        if (!dbPool) {
            return res.status(503).json({ error: 'База данных не доступна' });
        }

        // Проверяем, существует ли пользователь
        const [existingUsers] = await dbPool.execute(
            'SELECT id FROM users WHERE email = ?',
            [email]
        );

        if (existingUsers.length > 0) {
            return res.status(400).json({ error: 'Пользователь с таким email уже существует' });
        }

        // Хешируем пароль
        const passwordHash = await bcrypt.hash(password, 10);

        // Создаем пользователя
        const [result] = await dbPool.execute(
            'INSERT INTO users (email, password_hash, name) VALUES (?, ?, ?)',
            [email, passwordHash, name || null]
        );

        const userId = result.insertId;

        // Создаем JWT токен
        const token = jwt.sign(
            { id: userId, email: email },
            JWT_SECRET,
            { expiresIn: '30d' }
        );

        return res.status(201).json({
            token: token,
            user: {
                id: userId,
                email: email,
                name: name || null
            }
        });
    } catch (error) {
        console.error('Ошибка регистрации:', error);
        return res.status(500).json({ error: `Ошибка регистрации: ${error.message}` });
    }
});

/**
 * API endpoint для входа
 */
app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email и пароль обязательны' });
        }

        if (!dbPool) {
            return res.status(503).json({ error: 'База данных не доступна' });
        }

        // Находим пользователя
        const [users] = await dbPool.execute(
            'SELECT id, email, password_hash, name FROM users WHERE email = ?',
            [email]
        );

        if (users.length === 0) {
            return res.status(401).json({ error: 'Неверный email или пароль' });
        }

        const user = users[0];

        // Проверяем пароль
        const passwordMatch = await bcrypt.compare(password, user.password_hash);

        if (!passwordMatch) {
            return res.status(401).json({ error: 'Неверный email или пароль' });
        }

        // Создаем JWT токен
        const token = jwt.sign(
            { id: user.id, email: user.email },
            JWT_SECRET,
            { expiresIn: '30d' }
        );

        return res.json({
            token: token,
            user: {
                id: user.id,
                email: user.email,
                name: user.name
            }
        });
    } catch (error) {
        console.error('Ошибка входа:', error);
        return res.status(500).json({ error: `Ошибка входа: ${error.message}` });
    }
});

/**
 * API endpoint для обработки текста
 */
app.post('/api/process', optionalAuth, async (req, res) => {
    try {
        console.log('Получен запрос:', {
            method: req.method,
            url: req.url,
            contentType: req.get('Content-Type'),
            body: req.body
        });
        
        // Получаем данные из body
        let text = req.body?.text || req.body?.textInput || '';
        let exclude_words = req.body?.exclude_words || req.body?.excludeWords || req.body?.exclude || '';
        
        // Если body пустой, пробуем query параметры
        if (!text) {
            text = req.query.text || '';
        }
        if (!exclude_words) {
            exclude_words = req.query.exclude_words || '';
        }
        
        if (!text || !text.trim()) {
            console.log('Ошибка: текст пустой');
            return res.status(400).json({ error: 'Текст не может быть пустым' });
        }
        
        const result = processText(text.trim(), exclude_words ? exclude_words.trim() : '');
        
        if (result.error) {
            console.log('Ошибка обработки:', result.error);
            return res.status(400).json(result);
        }
        
        // Сохраняем запрос в базу данных
        if (dbPool) {
            try {
                const userIP = getUserIP(req);
                const userAgent = req.headers['user-agent'] || '';
                const requestText = text.trim();
                const excludeWords = exclude_words ? exclude_words.trim() : null;
                const resultText = result.result || '';
                const userId = req.user ? req.user.id : null;
                
                await dbPool.execute(
                    'INSERT INTO user_requests (user_ip, user_agent, request_text, exclude_words, result_text, user_id) VALUES (?, ?, ?, ?, ?, ?)',
                    [userIP, userAgent, requestText, excludeWords, resultText, userId]
                );
                console.log('Запрос сохранен в базу данных');
            } catch (dbError) {
                console.error('Ошибка сохранения в БД:', dbError.message);
                // Не прерываем выполнение, если ошибка БД
            }
        }
        
        console.log('Результат успешно обработан');
        return res.status(200).json(result);
    } catch (error) {
        console.error('Ошибка обработки:', error);
        return res.status(500).json({ error: `Ошибка обработки: ${error.message}` });
    }
});

/**
 * API endpoint для получения истории запросов
 */
app.get('/api/history', authenticateToken, async (req, res) => {
    try {
        if (!dbPool) {
            return res.status(503).json({ error: 'База данных не доступна' });
        }
        
        const limit = parseInt(req.query.limit) || 50;
        const offset = parseInt(req.query.offset) || 0;
        const userId = req.user.id;
        
        // Получаем историю запросов пользователя (LIMIT и OFFSET не могут быть параметрами)
        const [rows] = await dbPool.execute(
            `SELECT id, user_ip, request_text, exclude_words, result_text, created_at FROM user_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT ${limit} OFFSET ${offset}`,
            [userId]
        );
        
        // Получаем общее количество запросов
        const [countRows] = await dbPool.execute(
            'SELECT COUNT(*) as total FROM user_requests WHERE user_id = ?',
            [userId]
        );
        
        return res.json({
            requests: rows,
            total: countRows[0].total,
            limit: limit,
            offset: offset
        });
    } catch (error) {
        console.error('Ошибка получения истории:', error);
        return res.status(500).json({ error: `Ошибка получения истории: ${error.message}` });
    }
});

/**
 * API endpoint для получения всех запросов (административный)
 */
app.get('/api/all-requests', async (req, res) => {
    try {
        if (!dbPool) {
            return res.status(503).json({ error: 'База данных не доступна' });
        }
        
        const limit = parseInt(req.query.limit) || 100;
        const offset = parseInt(req.query.offset) || 0;
        
        // Получаем все запросы (LIMIT и OFFSET не могут быть параметрами)
        const [rows] = await dbPool.execute(
            `SELECT id, user_ip, user_agent, request_text, exclude_words, result_text, created_at FROM user_requests ORDER BY created_at DESC LIMIT ${limit} OFFSET ${offset}`
        );
        
        // Получаем общее количество запросов
        const [countRows] = await dbPool.execute('SELECT COUNT(*) as total FROM user_requests');
        
        return res.json({
            requests: rows,
            total: countRows[0].total,
            limit: limit,
            offset: offset
        });
    } catch (error) {
        console.error('Ошибка получения всех запросов:', error);
        return res.status(500).json({ error: `Ошибка получения запросов: ${error.message}` });
    }
});

/**
 * Проверка работоспособности API
 */
app.get('/api/health', async (req, res) => {
    const health = {
        status: 'ok',
        service: 'text-processor',
        database: 'unknown'
    };
    
    if (dbPool) {
        try {
            await dbPool.execute('SELECT 1');
            health.database = 'connected';
        } catch (error) {
            health.database = 'error: ' + error.message;
        }
    } else {
        health.database = 'not configured';
    }
    
    res.json(health);
});

/**
 * Корневой endpoint
 */
app.get('/', (req, res) => {
    res.json({
        service: 'Text Processor API',
        version: '1.0',
        runtime: 'Node.js',
        endpoints: {
            '/api/process': 'POST - обработка текста',
            '/api/history': 'GET - история запросов текущего пользователя',
            '/api/all-requests': 'GET - все запросы (административный)',
            '/api/health': 'GET - проверка работоспособности'
        }
    });
});

// Обработка 404 для API endpoints
app.use('/api', (req, res) => {
    res.status(404).json({ error: 'API endpoint не найден' });
});

// Обработка всех остальных ошибок
app.use((err, req, res, next) => {
    console.error('Ошибка:', err);
    if (req.path.startsWith('/api')) {
        return res.status(err.status || 500).json({ 
            error: err.message || 'Внутренняя ошибка сервера' 
        });
    }
    next(err);
});

// Запуск сервера
app.listen(PORT, '127.0.0.1', () => {
    console.log(`Text Processor API запущен на http://127.0.0.1:${PORT}`);
});

// Обработка ошибок
process.on('uncaughtException', (error) => {
    console.error('Необработанное исключение:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('Необработанное отклонение промиса:', reason);
    process.exit(1);
});

