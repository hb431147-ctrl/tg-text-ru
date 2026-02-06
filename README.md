# Настройка сайта tg-text.ru

Полная настройка сервера с nginx, SSL и автоматическим деплоем через Git.

## Быстрый старт

### 1. Подготовка SSL сертификатов

Если у вас есть сертификаты в формате .p7b или .der, конвертируйте их (см. `ssl_convert_guide.md`), затем загрузите на сервер:

```powershell
scp C:\tg\SSL\certificate.crt root@45.153.70.209:/etc/ssl/tg-text.ru/
scp C:\tg\SSL\private.key root@45.153.70.209:/etc/ssl/tg-text.ru/
```

### 2. Автоматическая настройка сервера

```powershell
# Загрузить все файлы на сервер
.\quick_setup.ps1

# Подключиться к серверу
ssh root@45.153.70.209

# На сервере выполнить:
chmod +x /root/server_setup.sh /root/setup_git_deploy.sh
/root/server_setup.sh
cp /root/nginx_tg-text.ru.conf /etc/nginx/conf.d/tg-text.ru.conf
chmod 644 /etc/ssl/tg-text.ru/certificate.crt
chmod 600 /etc/ssl/tg-text.ru/private.key
nginx -t && systemctl reload nginx
cp /root/index.html /var/www/tg-text.ru/
cp /root/post-receive /var/www/tg-text.ru/
cd /var/www/tg-text.ru && /root/setup_git_deploy.sh
```

### 3. Первый деплой

```powershell
# На локальной машине
.\deploy.ps1
```

Или вручную:

```powershell
cd C:\tg
git init
git add index.html
git commit -m "Initial commit"
git remote add production root@45.153.70.209:/var/www/tg-text.ru
git push production main
```

### 4. Проверка

Откройте в браузере: https://tg-text.ru

## Обновление сайта

Просто запустите:

```powershell
.\deploy.ps1
```

Сайт обновится автоматически без прерывания работы!

## Структура файлов

- `server_setup.sh` - скрипт настройки сервера (nginx, git)
- `setup_git_deploy.sh` - настройка Git для автоматического деплоя
- `nginx_tg-text.ru.conf` - конфигурация nginx с SSL
- `post-receive` - Git hook для автоматического деплоя
- `index.html` - главная страница сайта
- `deploy.ps1` - скрипт для быстрого деплоя с Windows
- `quick_setup.ps1` - скрипт для загрузки файлов на сервер
- `DEPLOY_INSTRUCTIONS.md` - подробная инструкция
- `ssl_convert_guide.md` - инструкция по конвертации SSL сертификатов

## Особенности

✅ Автоматический деплой через Git без прерывания работы сайта  
✅ SSL/HTTPS поддержка  
✅ Graceful reload nginx (без обрыва соединений)  
✅ Современные настройки безопасности  
✅ Красивый HTML с анимацией  

## Сервер

- IP: 45.153.70.209
- Домен: tg-text.ru
- ОС: Arch Linux
- Web сервер: Nginx
- Пользователь nginx: http (Arch Linux)

