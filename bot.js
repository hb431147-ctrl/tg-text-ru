#!/usr/bin/env node
/**
 * Telegram бот для обработки текста
 * Использует те же функции, что и веб-сайт
 */

const TelegramBot = require('node-telegram-bot-api');
const mysql = require('mysql2/promise');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// Импорт функций обработки текста из app.js
// Для этого нужно либо экспортировать функции из app.js, либо скопировать их сюда
// В данном случае скопируем функции для независимости

// Настройки
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production-2024';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || '';
const DEEPSEEK_API_URL = 'https://api.deepseek.com/v1/chat/completions';
const DEFAULT_PROMPT = 'Обработай текст по заданным правилам. Текст: {text}. Слова для исключения (и однокоренные): {exc}. Ответь только результатом, без пояснений.';

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

// Проверка токена бота
if (!BOT_TOKEN) {
    console.error('ОШИБКА: TELEGRAM_BOT_TOKEN не установлен!');
    console.error('Создайте бота через @BotFather и установите токен:');
    console.error('export TELEGRAM_BOT_TOKEN="your_token_here"');
    process.exit(1);
}

// Создание бота
const bot = new TelegramBot(BOT_TOKEN, { polling: true });

// Хранилище состояния пользователей (временное, можно заменить на БД)
const userState = new Map();

// Функции обработки текста (скопированы из app.js)
function getWordRoot(word) {
    word = word.toLowerCase().trim();
    if (word.length <= 3) return word;
    
    const endings = ['ый', 'ая', 'ое', 'ые', 'ой', 'ей', 'ом', 'ем', 'ую', 'ую',
                     'ов', 'ев', 'ин', 'ын', 'ых', 'их', 'ам', 'ям', 'ами', 'ями',
                     'ах', 'ях', 'и', 'ы', 'а', 'о', 'е', 'у', 'ю', 'ь', 'ъ'];
    
    for (let length = 3; length >= 1; length--) {
        if (word.length > length) {
            const ending = word.slice(-length);
            if (endings.includes(ending)) {
                return word.slice(0, -length);
            }
        }
    }
    
    return word.slice(0, Math.max(4, word.length - 2));
}

function areRelatedWords(word1, word2) {
    const root1 = getWordRoot(word1);
    const root2 = getWordRoot(word2);
    
    if (root1 === root2) return true;
    
    if (root1.length >= 4 && root2.length >= 4) {
        if (root1.includes(root2) || root2.includes(root1)) {
            return true;
        }
    }
    
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

function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

function processText(text, excludeWordsStr) {
    if (!text || !text.trim()) {
        return { error: 'Текст не может быть пустым' };
    }
    
    const words = text.match(/\S+/g) || [];
    
    if (words.length === 0) {
        return { error: 'Текст не содержит слов' };
    }
    
    const excludeWords = excludeWordsStr
        ? excludeWordsStr.split(',').map(w => w.trim().toLowerCase()).filter(w => w.length > 0)
        : [];
    
    const filteredWords = words.filter(word => {
        const wordLower = word.toLowerCase();
        
        if (excludeWords.includes(wordLower)) {
            return false;
        }
        
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
    
    const shuffledWords = shuffleArray(filteredWords);
    
    const resultParts = [];
    let wordIndex = 0;
    
    const segments = text.split(/(\s+)/);
    
    for (const segment of segments) {
        if (segment.trim() && !/^\s+$/.test(segment)) {
            if (wordIndex < shuffledWords.length) {
                resultParts.push(shuffledWords[wordIndex]);
                wordIndex++;
            }
        } else {
            resultParts.push(segment);
        }
    }
    
    while (wordIndex < shuffledWords.length) {
        resultParts.push((resultParts.length > 0 ? ' ' : '') + shuffledWords[wordIndex]);
        wordIndex++;
    }
    
    const result = resultParts.join('');
    
    return { result: result };
}

// Функция для авторизации пользователя через email и пароль
async function authenticateUser(email, password) {
    if (!dbPool) {
        return null;
    }
    
    try {
        // Находим пользователя по email
        const [users] = await dbPool.execute(
            'SELECT id, email, password_hash, name FROM users WHERE email = ?',
            [email]
        );
        
        if (users.length === 0) {
            return null;
        }
        
        const user = users[0];
        
        // Проверяем пароль
        const passwordMatch = await bcrypt.compare(password, user.password_hash);
        
        if (!passwordMatch) {
            return null;
        }
        
        return {
            id: user.id,
            email: user.email,
            name: user.name
        };
    } catch (error) {
        console.error('Ошибка авторизации:', error);
        return null;
    }
}

// Функция для привязки Telegram ID к пользователю
async function linkTelegramId(userId, telegramId) {
    if (!dbPool || !userId || !telegramId) {
        return false;
    }
    
    try {
        await dbPool.execute(
            'UPDATE users SET telegram_id = ? WHERE id = ?',
            [telegramId.toString(), userId]
        );
        return true;
    } catch (error) {
        console.error('Ошибка привязки Telegram ID:', error);
        return false;
    }
}

// Функция для получения пользователя по Telegram ID
async function getUserByTelegramId(telegramId) {
    if (!dbPool) {
        return null;
    }
    
    try {
        const [users] = await dbPool.execute(
            'SELECT id, email, name FROM users WHERE telegram_id = ?',
            [telegramId.toString()]
        );
        
        if (users.length > 0) {
            return users[0];
        }
        
        return null;
    } catch (error) {
        console.error('Ошибка получения пользователя:', error);
        return null;
    }
}

// Функция для сохранения запроса в БД
async function saveRequest(userId, requestText, excludeWords, resultText) {
    if (!dbPool || !userId) {
        return;
    }
    
    try {
        await dbPool.execute(
            'INSERT INTO user_requests (user_ip, user_agent, request_text, exclude_words, result_text, user_id) VALUES (?, ?, ?, ?, ?, ?)',
            ['telegram_bot', 'TelegramBot', requestText, excludeWords, resultText, userId]
        );
    } catch (error) {
        console.error('Ошибка сохранения запроса:', error);
    }
}

// Функция для получения истории пользователя (за последние 7 дней)
async function getUserHistory(userId, limit = 50) {
    if (!dbPool || !userId) return [];
    try {
        const [rows] = await dbPool.execute(
            `SELECT request_text, exclude_words, result_text, created_at 
             FROM user_requests 
             WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
             ORDER BY created_at DESC LIMIT ?`,
            [userId, limit]
        );
        return rows;
    } catch (error) {
        console.error('Ошибка получения истории:', error);
        return [];
    }
}

// Настройки пользователя (промпт и количество)
async function getUserSettings(userId) {
    if (!dbPool || !userId) return { prompt_template: null, request_count: 1 };
    try {
        const [rows] = await dbPool.execute(
            'SELECT prompt_template, request_count FROM users WHERE id = ?',
            [userId]
        );
        if (rows.length === 0) return { prompt_template: null, request_count: 1 };
        const r = rows[0];
        return {
            prompt_template: r.prompt_template || null,
            request_count: Math.max(1, parseInt(r.request_count, 10) || 1),
        };
    } catch (e) {
        console.error('getUserSettings:', e);
        return { prompt_template: null, request_count: 1 };
    }
}

async function updateUserPrompt(userId, promptTemplate) {
    if (!dbPool || !userId) return false;
    try {
        await dbPool.execute('UPDATE users SET prompt_template = ? WHERE id = ?', [promptTemplate || null, userId]);
        return true;
    } catch (e) {
        console.error('updateUserPrompt:', e);
        return false;
    }
}

async function updateUserCount(userId, count) {
    if (!dbPool || !userId) return false;
    const n = Math.max(1, Math.min(10, parseInt(count, 10) || 1));
    try {
        await dbPool.execute('UPDATE users SET request_count = ? WHERE id = ?', [n, userId]);
        return n;
    } catch (e) {
        console.error('updateUserCount:', e);
        return false;
    }
}

// Вызов DeepSeek API
async function callDeepSeek(promptText) {
    if (!DEEPSEEK_API_KEY) {
        return { error: 'DeepSeek API ключ не настроен на сервере' };
    }
    const res = await fetch(DEEPSEEK_API_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        },
        body: JSON.stringify({
            model: 'deepseek-chat',
            messages: [{ role: 'user', content: promptText }],
            max_tokens: 4096,
            temperature: 0.7,
        }),
    });
    if (!res.ok) {
        const errText = await res.text();
        return { error: `API: ${res.status} ${errText.slice(0, 150)}` };
    }
    const data = await res.json();
    const content = data.choices?.[0]?.message?.content?.trim() || '';
    return { result: content || '(пустой ответ)' };
}

// Обработчик команды /start
bot.onText(/\/start/, async (msg) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    const firstName = msg.from.first_name;
    
    // Проверяем, авторизован ли пользователь
    const user = await getUserByTelegramId(telegramId);
    
    if (user) {
        // Пользователь уже авторизован
        const welcomeMessage = `👋 Привет, ${firstName || user.name}!

Вы авторизованы как: ${user.email}

Я бот для обработки текста. Я могу:
• Перемешивать слова в тексте
• Исключать указанные слова и однокоренные
• Сохранять историю ваших запросов

📝 Просто отправь мне текст, и я его обработаю!

Команды:
/help - справка
/prompt <текст> - установить промпт ({text} и {exc})
/count <число> - количество запросов подряд (1-10)
/process <текст> - обработать текст
/exclude <слова> - установить слова для исключения
/history - показать историю (7 дней)
/clear - очистить настройки
/logout - выйти из аккаунта`;

        bot.sendMessage(chatId, welcomeMessage);
        
        // Инициализируем состояние пользователя
        if (!userState.has(chatId)) {
            userState.set(chatId, {
                excludeWords: '',
                userId: user.id,
                email: user.email
            });
        } else {
            userState.get(chatId).userId = user.id;
            userState.get(chatId).email = user.email;
        }
    } else {
        // Пользователь не авторизован
        const welcomeMessage = `👋 Привет, ${firstName || 'друг'}!

Для использования бота необходимо авторизоваться.

🔐 Авторизация:
/auth <email> <пароль>

Пример:
/auth user@example.com mypassword

После авторизации вы сможете:
• Обрабатывать текст
• Просматривать историю запросов
• Использовать все функции бота`;

        bot.sendMessage(chatId, welcomeMessage);
        
        // Инициализируем состояние пользователя (без авторизации)
        if (!userState.has(chatId)) {
            userState.set(chatId, {
                excludeWords: '',
                userId: null,
                email: null
            });
        }
    }
});

// Обработчик команды /help
bot.onText(/\/help/, (msg) => {
    const chatId = msg.chat.id;
    
    const helpMessage = `📖 Справка по использованию бота:

🔐 Авторизация:
/auth <email> <пароль> - войти в аккаунт
/logout - выйти из аккаунта

📝 Промпт и количество:
/prompt <текст> - установить промпт (переменные {text} и {exc})
/count <1-10> - сколько раз подряд выполнять запрос (по умолчанию 1)

1️⃣ Обработка текста:
   Просто отправь текст сообщением — бот перемешает слова и вернёт результат.
   Или: /process <текст>

2️⃣ Исключение слов (работает вместе с обработкой):
   Сначала: /exclude слово1, слово2, слово3
   Потом отправь любой текст (сообщением или /process <текст>).
   В результате будут убраны указанные слова и однокоренные, остальные перемешаны.
   Эти настройки действуют, пока не введёшь новый /exclude или /clear.

3️⃣ История:
   /history - последние запросы (хранятся 7 дней)

4️⃣ Очистка:
   /clear - убрать настройки исключений (слова для исключения сбросятся)

Пример:
• /exclude привет, дела
• Отправь: "Привет мир как дела"
→ В ответе не будет "привет", "дела" и однокоренных, остальные слова перемешаны.

⚠️ Для использования бота нужна авторизация: /auth <email> <пароль>`;

    bot.sendMessage(chatId, helpMessage);
});

// Обработчик команды /exclude
bot.onText(/\/exclude (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    const excludeWords = match[1].trim();
    
    // Проверяем авторизацию
    const user = await getUserByTelegramId(telegramId);
    
    if (!user) {
        bot.sendMessage(chatId, '❌ Вы не авторизованы.\n\nИспользуйте команду /auth <email> <пароль> для входа.');
        return;
    }
    
    if (!userState.has(chatId)) {
        userState.set(chatId, { 
            excludeWords: '', 
            userId: user.id,
            email: user.email
        });
    }
    
    userState.get(chatId).excludeWords = excludeWords;
    
    bot.sendMessage(chatId, `✅ Слова для исключения установлены:\n${excludeWords}\n\nТеперь отправь текст для обработки.`);
});

// Обработчик команды /prompt
bot.onText(/\/prompt ([\s\S]+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    const user = await getUserByTelegramId(telegramId);
    if (!user) {
        bot.sendMessage(chatId, '❌ Сначала авторизуйтесь: /auth <email> <пароль>');
        return;
    }
    const promptText = match[1].trim();
    await updateUserPrompt(user.id, promptText);
    bot.sendMessage(chatId, `✅ Промпт установлен. В нём можно использовать переменные {text} и {exc}.`);
});

bot.onText(/\/prompt$/, (msg) => {
    bot.sendMessage(msg.chat.id, 'Использование: /prompt <текст промта>\nПример: /prompt Обработай текст: {text}. Исключи: {exc}.');
});

// Обработчик команды /count
bot.onText(/\/count (\d+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    const user = await getUserByTelegramId(telegramId);
    if (!user) {
        bot.sendMessage(chatId, '❌ Сначала авторизуйтесь: /auth <email> <пароль>');
        return;
    }
    const n = await updateUserCount(user.id, match[1]);
    if (n !== false) {
        bot.sendMessage(chatId, `✅ Количество запросов подряд: ${n}`);
    } else {
        bot.sendMessage(chatId, '❌ Ошибка сохранения. Допустимо число от 1 до 10.');
    }
});

bot.onText(/\/count$/, (msg) => {
    bot.sendMessage(msg.chat.id, 'Использование: /count <число от 1 до 10>\nСколько раз подряд выполнять запрос к нейросети.');
});

// Обработчик команды /clear
bot.onText(/\/clear/, async (msg) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    
    // Проверяем авторизацию
    const user = await getUserByTelegramId(telegramId);
    
    if (!user) {
        bot.sendMessage(chatId, '❌ Вы не авторизованы.\n\nИспользуйте команду /auth <email> <пароль> для входа.');
        return;
    }
    
    if (userState.has(chatId)) {
        userState.get(chatId).excludeWords = '';
    }
    
    bot.sendMessage(chatId, '✅ Настройки очищены. Слова для исключения удалены.');
});

// Обработчик команды /auth
bot.onText(/\/auth (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    const args = match[1].trim().split(/\s+/);
    
    if (args.length < 2) {
        bot.sendMessage(chatId, '❌ Неверный формат команды.\n\nИспользование: /auth <email> <пароль>\n\nПример: /auth user@example.com mypassword');
        return;
    }
    
    const email = args[0];
    const password = args.slice(1).join(' '); // Пароль может содержать пробелы
    
    bot.sendMessage(chatId, '⏳ Проверка данных...');
    
    const user = await authenticateUser(email, password);
    
    if (!user) {
        bot.sendMessage(chatId, '❌ Неверный email или пароль.\n\nПроверьте правильность введенных данных.\nЕсли у вас нет аккаунта, зарегистрируйтесь на сайте:\nhttps://tg-text.ru/register');
        return;
    }
    
    // Привязываем Telegram ID к пользователю
    await linkTelegramId(user.id, telegramId);
    
    // Сохраняем в состоянии
    if (!userState.has(chatId)) {
        userState.set(chatId, {
            excludeWords: '',
            userId: user.id,
            email: user.email
        });
    } else {
        userState.get(chatId).userId = user.id;
        userState.get(chatId).email = user.email;
    }
    
    const commandsList = `
📋 Доступные команды:

/help — справка по использованию
/process <текст> — обработать текст (или просто отправь текст сообщением)
/exclude <слова через запятую> — установить слова для исключения
/clear — очистить настройки исключений
/history — показать историю запросов (последние 10)
/logout — выйти из аккаунта

💡 Как работают /exclude и обработка текста:
1) Командой /exclude задаёшь слова, которые не должны попадать в результат (и однокоренные к ним).
2) Потом отправляешь любой текст сообщением или командой /process <текст>.
3) Бот перемешает слова в тексте и уберёт указанные (и однокоренные). Настройки исключений действуют, пока не отправишь новый /exclude или /clear.`;

    bot.sendMessage(chatId, `✅ Авторизация успешна!\n\nВы вошли как: ${user.email}\nИмя: ${user.name || 'не указано'}\n\nТеперь вы можете использовать все функции бота.${commandsList}`);
});

// Обработчик команды /logout
bot.onText(/\/logout/, async (msg) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    
    // Удаляем привязку Telegram ID (опционально, можно оставить для истории)
    // await unlinkTelegramId(telegramId);
    
    // Очищаем состояние
    if (userState.has(chatId)) {
        userState.get(chatId).userId = null;
        userState.get(chatId).email = null;
        userState.get(chatId).excludeWords = '';
    }
    
    bot.sendMessage(chatId, '✅ Вы вышли из аккаунта.\n\nДля продолжения работы используйте команду /auth');
});

// Обработчик команды /history
bot.onText(/\/history/, async (msg) => {
    const chatId = msg.chat.id;
    const telegramId = msg.from.id;
    
    // Проверяем авторизацию
    const user = await getUserByTelegramId(telegramId);
    
    if (!user) {
        bot.sendMessage(chatId, '❌ Вы не авторизованы.\n\nИспользуйте команду /auth <email> <пароль> для входа.');
        return;
    }
    
    // Обновляем состояние
    if (userState.has(chatId)) {
        userState.get(chatId).userId = user.id;
        userState.get(chatId).email = user.email;
    }
    
    const history = await getUserHistory(user.id, 10);
    
    if (history.length === 0) {
        bot.sendMessage(chatId, '📝 История запросов пуста.');
        return;
    }
    
    let historyText = '📜 История запросов (за последние 7 дней):\n\n';
    
    history.forEach((item, index) => {
        const date = new Date(item.created_at).toLocaleString('ru-RU');
        historyText += `${index + 1}. ${date}\n`;
        historyText += `   Запрос: ${item.request_text.substring(0, 50)}${item.request_text.length > 50 ? '...' : ''}\n`;
        if (item.exclude_words) {
            historyText += `   Исключено: ${item.exclude_words}\n`;
        }
        historyText += `   Результат: ${item.result_text.substring(0, 50)}${item.result_text.length > 50 ? '...' : ''}\n\n`;
    });
    
    bot.sendMessage(chatId, historyText);
});

// Обработчик команды /process
bot.onText(/\/process (.+)/, async (msg, match) => {
    const chatId = msg.chat.id;
    const text = match[1].trim();
    
    await processTextMessage(chatId, text, msg.from.id);
});

// Обработчик обычных текстовых сообщений
bot.on('message', async (msg) => {
    // Пропускаем команды
    if (msg.text && msg.text.startsWith('/')) {
        return;
    }
    
    // Обрабатываем только текстовые сообщения
    if (msg.text) {
        const chatId = msg.chat.id;
        await processTextMessage(chatId, msg.text, msg.from.id);
    }
});

// Функция обработки текста (DeepSeek: промпт с {text} и {exc}, количество запросов)
async function processTextMessage(chatId, text, telegramId) {
    try {
        const user = await getUserByTelegramId(telegramId);
        if (!user) {
            bot.sendMessage(chatId, '❌ Вы не авторизованы.\n\nИспользуйте: /auth <email> <пароль>\nРегистрация: https://tg-text.ru/register');
            return;
        }

        if (userState.has(chatId)) {
            userState.get(chatId).userId = user.id;
            userState.get(chatId).email = user.email;
        } else {
            userState.set(chatId, { excludeWords: '', userId: user.id, email: user.email });
        }

        const excludeWords = userState.has(chatId) ? userState.get(chatId).excludeWords : '';
        const settings = await getUserSettings(user.id);
        const promptTemplate = settings.prompt_template || DEFAULT_PROMPT;
        const requestCount = settings.request_count;

        const filledPrompt = String(promptTemplate)
            .replace(/\{text\}/g, text.trim())
            .replace(/\{exc\}/g, excludeWords ? String(excludeWords).trim() : '');

        const results = [];
        for (let i = 0; i < requestCount; i++) {
            const result = await callDeepSeek(filledPrompt);
            if (result.error) {
                bot.sendMessage(chatId, `❌ Ошибка: ${result.error}`);
                return;
            }
            results.push(result.result);
            await saveRequest(user.id, text, excludeWords || null, result.result);
        }

        const resultMessage = results.length === 1
            ? `✅ Результат:\n\n${results[0]}`
            : `✅ Результаты (${results.length}):\n\n${results.map((r, i) => `--- ${i + 1} ---\n${r}`).join('\n\n')}`;
        bot.sendMessage(chatId, resultMessage);
    } catch (error) {
        console.error('Ошибка обработки сообщения:', error);
        bot.sendMessage(chatId, '❌ Ошибка при обработке. Попробуйте позже.');
    }
}

// Обработка ошибок
bot.on('polling_error', (error) => {
    console.error('Ошибка polling:', error);
});

// Запуск бота
console.log('🤖 Telegram бот запущен и готов к работе!');
console.log('Используйте /start в Telegram для начала работы.');

