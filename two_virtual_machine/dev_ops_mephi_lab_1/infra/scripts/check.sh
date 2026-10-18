#!/bin/bash
#
# check-stand.sh — проверка стенда DevOps (ЛР1)
# Запуск: bash scripts/check-stand.sh
#

SSH_KEY="${SSH_KEY:-$HOME/.ssh/student_key}"
SSH_OPTS="-i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o LogLevel=ERROR"
NODE1="192.168.56.11"
NODE2="192.168.56.12"
PORT_CLOSED="8443"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
    local desc="$1" result="$2"
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗${NC} $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "=========================================="
echo "  Проверка стенда DevOps (ЛР1)"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# --- SSH по ключу ---
echo "--- SSH по ключу ---"
ssh $SSH_OPTS student@$NODE1 "true" 2>/dev/null
check "SSH на node-1 ($NODE1)" $?

ssh $SSH_OPTS student@$NODE2 "true" 2>/dev/null
check "SSH на node-2 ($NODE2)" $?

# --- Парольный вход отклонён ---
echo ""
echo "--- Парольный вход (должен быть отклонён) ---"
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    -o ConnectTimeout=5 student@$NODE1 "true" 2>/dev/null
[ $? -ne 0 ] && check "Парольный вход на node-1 отклонён" 0 \
             || check "Парольный вход на node-1 отклонён" 1

# --- Docker без sudo ---
echo ""
echo "--- Docker без sudo ---"
ssh $SSH_OPTS student@$NODE1 "docker run --rm hello-world" >/dev/null 2>&1
check "Docker без sudo на node-1" $?

ssh $SSH_OPTS student@$NODE2 "docker run --rm hello-world" >/dev/null 2>&1
check "Docker без sudo на node-2" $?

# --- Связность узлов по именам ---
echo ""
echo "--- Связность узлов ---"
ssh $SSH_OPTS student@$NODE1 "ping -c1 -W2 node-2" >/dev/null 2>&1
check "node-1 видит node-2 по имени" $?

ssh $SSH_OPTS student@$NODE2 "ping -c1 -W2 node-1" >/dev/null 2>&1
check "node-2 видит node-1 по имени" $?

# --- Пользователь app без sudo ---
echo ""
echo "--- Пользователь app ---"
ssh $SSH_OPTS student@$NODE1 "id app" >/dev/null 2>&1
check "Пользователь app существует на node-1" $?

ssh $SSH_OPTS student@$NODE1 "sudo -l -U app 2>/dev/null | grep -q sudo" 2>/dev/null
[ $? -ne 0 ] && check "Пользователь app без sudo" 0 \
             || check "Пользователь app без sudo" 1

# --- Закрытый порт на node-2 ---
echo ""
echo "--- Порт $PORT_CLOSED на node-2 (должен быть закрыт) ---"
nc -z -w2 $NODE2 $PORT_CLOSED 2>/dev/null
[ $? -ne 0 ] && check "Порт $PORT_CLOSED на node-2 закрыт" 0 \
             || check "Порт $PORT_CLOSED на node-2 закрыт" 1

# --- Итог ---
echo ""
echo "=========================================="
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}ВСЁ ОК: $PASS из $((PASS + FAIL)) проверок пройдено${NC}"
    exit 0
else
    echo -e "${YELLOW}Пройдено: $PASS | Провалено: $FAIL${NC}"
    exit 1
fi