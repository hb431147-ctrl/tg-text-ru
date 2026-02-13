# Создание нового SSH ключа для сервера

## Вариант 1: Создать новый ключ с другим именем

```powershell
ssh-keygen -t ed25519 -f C:\Users\vsush\.ssh\id_ed25519_tg_text -C "tg-text.ru server"
```

Или RSA ключ:
```powershell
ssh-keygen -t rsa -b 4096 -f C:\Users\vsush\.ssh\id_rsa_tg_text -C "tg-text.ru server"
```

## Вариант 2: Перезаписать существующий ключ (ОСТОРОЖНО!)

```powershell
ssh-keygen -t ed25519 -f C:\Users\vsush\.ssh\id_rsa -C "tg-text.ru server"
```

## После создания ключа:

1. Просмотрите публичный ключ:
```powershell
type C:\Users\vsush\.ssh\id_ed25519_tg_text.pub
```

2. Скопируйте публичный ключ и добавьте на сервер:
```bash
ssh root@45.153.70.209
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
# Вставьте публичный ключ
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

3. Подключитесь с новым ключом:
```powershell
ssh -i C:\Users\vsush\.ssh\id_ed25519_tg_text root@45.153.70.209
```

## Вариант 3: Использовать пароль для подключения

Если у вас есть пароль root, подключитесь так:
```powershell
ssh root@45.153.70.209
```

Затем добавьте ваш существующий публичный ключ:
```powershell
type C:\Users\vsush\.ssh\id_rsa.pub
```

Скопируйте вывод и на сервере выполните:
```bash
mkdir -p ~/.ssh
echo "ваш_публичный_ключ" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

