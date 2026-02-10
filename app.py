#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API сервер для обработки текста
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import re
import random

app = Flask(__name__)
CORS(app)  # Разрешаем CORS для работы с фронтендом


def get_word_root(word):
    """Получить корень слова (упрощенный алгоритм)"""
    word = word.lower().strip()
    if len(word) <= 3:
        return word
    
    # Типичные окончания русского языка
    endings = ['ый', 'ая', 'ое', 'ые', 'ой', 'ей', 'ом', 'ем', 'ую', 'ую',
               'ов', 'ев', 'ин', 'ын', 'ых', 'их', 'ам', 'ям', 'ами', 'ями',
               'ах', 'ях', 'и', 'ы', 'а', 'о', 'е', 'у', 'ю', 'ь', 'ъ']
    
    # Пробуем убрать окончания разной длины
    for length in range(3, 0, -1):
        if len(word) > length:
            ending = word[-length:]
            if ending in endings:
                return word[:-length]
    
    # Если окончание не найдено, возвращаем первые 4-5 символов как корень
    return word[:max(4, len(word) - 2)]


def are_related_words(word1, word2):
    """Проверка, являются ли слова однокоренными"""
    root1 = get_word_root(word1)
    root2 = get_word_root(word2)
    
    # Сравниваем корни
    if root1 == root2:
        return True
    
    # Проверяем, содержит ли один корень другой
    if len(root1) >= 4 and len(root2) >= 4:
        if root2 in root1 or root1 in root2:
            return True
    
    # Проверяем общий префикс длиной 4+ символов
    common_prefix = ''
    min_len = min(len(root1), len(root2))
    for i in range(min_len):
        if root1[i] == root2[i]:
            common_prefix += root1[i]
        else:
            break
    
    return len(common_prefix) >= 4


def shuffle_array(array):
    """Перемешивание массива (алгоритм Фишера-Йетса)"""
    shuffled = array.copy()
    for i in range(len(shuffled) - 1, 0, -1):
        j = random.randint(0, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    return shuffled


def process_text(text, exclude_words_str):
    """Основная функция обработки текста"""
    if not text or not text.strip():
        return {'error': 'Текст не может быть пустым'}, 400
    
    # Разбиваем текст на слова
    words = re.findall(r'\S+', text)
    
    if not words:
        return {'error': 'Текст не содержит слов'}, 400
    
    # Получаем список слов для исключения
    exclude_words = []
    if exclude_words_str:
        exclude_words = [w.strip().lower() for w in exclude_words_str.split(',') if w.strip()]
    
    # Фильтруем слова: исключаем указанные и однокоренные
    filtered_words = []
    for word in words:
        word_lower = word.lower()
        
        # Проверяем точное совпадение
        if word_lower in exclude_words:
            continue
        
        # Проверяем однокоренные слова
        should_exclude = False
        for exclude_word in exclude_words:
            if are_related_words(word_lower, exclude_word):
                should_exclude = True
                break
        
        if not should_exclude:
            filtered_words.append(word)
    
    if not filtered_words:
        return {'result': 'Все слова были исключены. Результат пуст.'}, 200
    
    # Перемешиваем оставшиеся слова
    shuffled_words = shuffle_array(filtered_words)
    
    # Формируем результат, сохраняя структуру текста
    result_parts = []
    word_index = 0
    
    # Разбиваем исходный текст на сегменты (слова и пробелы)
    segments = re.split(r'(\s+)', text)
    
    for segment in segments:
        if segment.strip() and not re.match(r'^\s+$', segment):
            # Это слово
            if word_index < len(shuffled_words):
                result_parts.append(shuffled_words[word_index])
                word_index += 1
        else:
            # Это пробелы или знаки препинания
            result_parts.append(segment)
    
    # Если остались слова после обработки
    while word_index < len(shuffled_words):
        result_parts.append(' ' + shuffled_words[word_index] if result_parts else shuffled_words[word_index])
        word_index += 1
    
    result = ''.join(result_parts)
    
    return {'result': result}, 200


@app.route('/api/process', methods=['POST'])
def api_process():
    """API endpoint для обработки текста"""
    try:
        # Пробуем получить данные из JSON
        data = None
        if request.is_json:
            data = request.get_json()
        elif request.data:
            import json
            try:
                data = json.loads(request.data.decode('utf-8'))
            except:
                pass
        
        # Если JSON не получился, пробуем form-data или query string
        if not data:
            text = request.form.get('text', '') or request.args.get('text', '')
            exclude_words = request.form.get('exclude_words', '') or request.args.get('exclude_words', '')
        else:
            text = data.get('text', '').strip()
            exclude_words = data.get('exclude_words', '').strip()
        
        if not text:
            return jsonify({'error': 'Текст не может быть пустым'}), 400
        
        result, status_code = process_text(text, exclude_words)
        return jsonify(result), status_code
    
    except Exception as e:
        return jsonify({'error': f'Ошибка обработки: {str(e)}'}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """Проверка работоспособности API"""
    return jsonify({'status': 'ok', 'service': 'text-processor'}), 200


@app.route('/', methods=['GET'])
def index():
    """Корневой endpoint"""
    return jsonify({
        'service': 'Text Processor API',
        'version': '1.0',
        'endpoints': {
            '/api/process': 'POST - обработка текста',
            '/api/health': 'GET - проверка работоспособности'
        }
    }), 200


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=False)

