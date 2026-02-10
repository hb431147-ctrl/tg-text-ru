#!/usr/bin/env node
/**
 * API сервер для обработки текста (Node.js)
 */

const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware для логирования
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
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

// Парсинг JSON с обработкой ошибок
app.use(express.json({ 
    limit: '10mb',
    verify: (req, res, buf) => {
        try {
            JSON.parse(buf.toString());
        } catch (e) {
            console.error('Ошибка парсинга JSON:', e.message);
            console.error('Буфер:', buf.toString());
        }
    }
}));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Обработка ошибок парсинга JSON
app.use((err, req, res, next) => {
    if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
        console.error('Ошибка парсинга JSON:', err.message);
        return res.status(400).json({ error: 'Неверный формат JSON: ' + err.message });
    }
    next();
});

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
 * API endpoint для обработки текста
 */
app.post('/api/process', (req, res) => {
    try {
        console.log('Получен запрос:', {
            method: req.method,
            url: req.url,
            headers: req.headers,
            body: req.body
        });
        
        const { text, exclude_words } = req.body;
        
        if (!text || !text.trim()) {
            console.log('Ошибка: текст пустой');
            return res.status(400).json({ error: 'Текст не может быть пустым' });
        }
        
        const result = processText(text.trim(), exclude_words ? exclude_words.trim() : '');
        
        if (result.error) {
            console.log('Ошибка обработки:', result.error);
            return res.status(400).json(result);
        }
        
        console.log('Результат успешно обработан');
        return res.status(200).json(result);
    } catch (error) {
        console.error('Ошибка обработки:', error);
        return res.status(500).json({ error: `Ошибка обработки: ${error.message}` });
    }
});

/**
 * Проверка работоспособности API
 */
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', service: 'text-processor' });
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
            '/api/health': 'GET - проверка работоспособности'
        }
    });
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

