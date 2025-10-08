#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Директория установки
INSTALL_DIR="$HOME/unichain-node"

# Функция для вывода заголовка
print_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}       🦄 Unichain Node Installation 🦄${NC}"
    echo -e "${CYAN}  DeFi-native Ethereum L2 Node Setup${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

# Функция для вывода сообщений
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Проверка системных требований
check_requirements() {
    print_info "Проверка системных требований..."
    echo ""
    
    # CPU
    CPU_CORES=$(nproc)
    if [ $CPU_CORES -ge 4 ]; then
        print_success "CPU: $CPU_CORES ядер (рекомендуется: 4+)"
    else
        print_warning "CPU: $CPU_CORES ядер (рекомендуется: 4+)"
    fi
    
    # RAM
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ $RAM_GB -ge 8 ]; then
        print_success "RAM: ${RAM_GB}GB (рекомендуется: 8GB+)"
    else
        print_warning "RAM: ${RAM_GB}GB (рекомендуется: 8GB+)"
    fi
    
    # Disk
    DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $DISK_GB -ge 100 ]; then
        print_success "Свободное место: ${DISK_GB}GB (рекомендуется: 100GB+)"
    else
        print_warning "Свободное место: ${DISK_GB}GB (рекомендуется: 100GB+)"
    fi
    
    echo ""
}

# Обновление системы
update_system() {
    print_info "Обновление системы..."
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y ca-certificates curl gnupg lsb-release git wget jq screen
    print_success "Система обновлена"
}

# Установка Docker
install_docker() {
    print_info "Проверка установки Docker..."
    
    if command -v docker &> /dev/null; then
        print_success "Docker уже установлен"
        docker --version
        return 0
    fi
    
    print_info "Установка Docker..."
    
    # Удаление старых версий
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
        sudo apt-get remove -y $pkg 2>/dev/null
    done
    
    # Установка Docker
    sudo apt install -y docker.io
    
    # Запуск и автозапуск Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Добавление пользователя в группу docker
    sudo groupadd docker 2>/dev/null
    sudo usermod -aG docker $USER
    
    print_success "Docker установлен"
    print_warning "Выполните 'newgrp docker' или перелогиньтесь для применения прав"
}

# Установка Docker Compose
install_docker_compose() {
    print_info "Проверка установки Docker Compose..."
    
    if docker compose version &> /dev/null; then
        print_success "Docker Compose уже установлен"
        docker compose version
        return 0
    fi
    
    print_info "Установка Docker Compose..."
    
    # Получение последней версии
    VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    if [ -z "$VER" ]; then
        VER="v2.20.2"
        print_warning "Не удалось получить последнюю версию, используется $VER"
    fi
    
    sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Создание симлинка для docker compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose установлен"
    docker-compose --version
}

# Клонирование репозитория Unichain
clone_unichain_repo() {
    print_info "Клонирование репозитория Unichain Node..."
    
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Директория $INSTALL_DIR уже существует"
        read -p "Удалить и переустановить? (y/n): " REINSTALL
        if [[ "$REINSTALL" == "y" || "$REINSTALL" == "Y" ]]; then
            print_info "Остановка существующей ноды..."
            cd "$INSTALL_DIR" && docker-compose down 2>/dev/null
            cd ~
            rm -rf "$INSTALL_DIR"
        else
            cd "$INSTALL_DIR"
            return 0
        fi
    fi
    
    git clone https://github.com/Uniswap/unichain-node.git "$INSTALL_DIR"
    
    if [ $? -eq 0 ]; then
        print_success "Репозиторий успешно клонирован"
        cd "$INSTALL_DIR"
        return 0
    else
        print_error "Ошибка при клонировании репозитория"
        return 1
    fi
}

# Настройка RPC эндпоинтов
configure_rpc() {
    local NETWORK=$1
    local ENV_FILE=""
    
    if [ "$NETWORK" == "mainnet" ]; then
        ENV_FILE=".env.mainnet"
    else
        ENV_FILE=".env.sepolia"
    fi
    
    cd "$INSTALL_DIR"
    
    print_info "Настройка RPC эндпоинтов для $NETWORK..."
    echo ""
    
    print_info "Вам нужны L1 Ethereum RPC эндпоинты:"
    print_info "1. Ethereum Execution Layer RPC (OP_NODE_L1_ETH_RPC)"
    print_info "2. Ethereum Beacon Chain RPC (OP_NODE_L1_BEACON)"
    echo ""
    
    # Публичные RPC по умолчанию
    if [ "$NETWORK" == "sepolia" ]; then
        DEFAULT_ETH_RPC="https://ethereum-sepolia-rpc.publicnode.com"
        DEFAULT_BEACON_RPC="https://ethereum-sepolia-beacon-api.publicnode.com"
    else
        DEFAULT_ETH_RPC="https://ethereum-rpc.publicnode.com"
        DEFAULT_BEACON_RPC="https://ethereum-beacon-api.publicnode.com"
    fi
    
    print_info "Публичные RPC по умолчанию:"
    echo "  ETH RPC: $DEFAULT_ETH_RPC"
    echo "  Beacon RPC: $DEFAULT_BEACON_RPC"
    echo ""
    
    read -p "Использовать публичные RPC? (y/n): " USE_PUBLIC
    
    if [[ "$USE_PUBLIC" == "y" || "$USE_PUBLIC" == "Y" ]]; then
        ETH_RPC="$DEFAULT_ETH_RPC"
        BEACON_RPC="$DEFAULT_BEACON_RPC"
        print_success "Будут использованы публичные RPC"
    else
        read -p "Введите Ethereum L1 Execution RPC URL: " ETH_RPC
        read -p "Введите Ethereum L1 Beacon RPC URL: " BEACON_RPC
    fi
    
    # Настройка .env файла
    if [ -f "$ENV_FILE" ]; then
        # Обновление RPC эндпоинтов
        sed -i "s|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$ETH_RPC|" "$ENV_FILE"
        sed -i "s|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$BEACON_RPC|" "$ENV_FILE"
        print_success "RPC эндпоинты настроены в $ENV_FILE"
    else
        print_error "Файл $ENV_FILE не найден"
        return 1
    fi
}

# Настройка docker-compose для выбранной сети
configure_network() {
    local NETWORK=$1
    cd "$INSTALL_DIR"
    
    print_info "Настройка docker-compose.yml для сети: $NETWORK..."
    
    # Редактируем docker-compose.yml вручную через nano
    print_warning "Необходимо вручную отредактировать docker-compose.yml"
    echo ""
    print_info "Инструкция:"
    print_info "1. Найдите секцию 'execution-client:' и 'env_file:'"
    print_info "2. Раскомментируйте (уберите #) перед нужной сетью:"
    
    if [ "$NETWORK" == "mainnet" ]; then
        print_info "   - .env.mainnet  (раскомментируйте эту строку)"
        print_info "   # - .env.sepolia  (закомментируйте эту строку)"
    else
        print_info "   - .env.sepolia  (раскомментируйте эту строку)"
        print_info "   # - .env.mainnet  (закомментируйте эту строку)"
    fi
    
    print_info "3. То же самое для секции 'op-node:' и 'env_file:'"
    print_info "4. Сохраните: Ctrl+X, затем Y, затем Enter"
    echo ""
    
    read -p "Нажмите Enter чтобы открыть редактор..."
    nano docker-compose.yml
    
    # Проверка конфигурации
    if docker-compose config > /dev/null 2>&1; then
        print_success "Конфигурация валидна!"
        return 0
    else
        print_error "Ошибка в конфигурации!"
        print_info "Запустите: cd $INSTALL_DIR && docker-compose config"
        return 1
    fi
}

# Установка Unichain ноды
install_unichain_node() {
    print_header
    echo -e "${BLUE}Выберите сеть для установки:${NC}"
    echo ""
    echo "  1) Mainnet (Основная сеть)"
    echo "  2) Sepolia (Тестовая сеть)"
    echo "  0) Назад"
    echo ""
    read -p "Ваш выбор: " network_choice
    
    case $network_choice in
        1)
            NETWORK="mainnet"
            ;;
        2)
            NETWORK="sepolia"
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Неверный выбор"
            sleep 2
            return 1
            ;;
    esac
    
    echo ""
    check_requirements
    
    read -p "Продолжить установку? (y/n): " CONTINUE
    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
        return 0
    fi
    
    # Обновление системы
    update_system
    
    # Установка Docker
    install_docker
    
    # Установка Docker Compose
    install_docker_compose
    
    # Применение прав docker
    print_info "Применение прав docker..."
    newgrp docker << END
    echo "Права docker применены"
END
    
    # Клонирование репозитория
    clone_unichain_repo
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Настройка RPC
    configure_rpc "$NETWORK"
    
    # Настройка сети в docker-compose
    configure_network "$NETWORK"
    
    echo ""
    print_success "Установка завершена!"
    print_info "Для запуска ноды используйте опцию 2 в главном меню"
}

# Запуск ноды
start_node() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Нода не установлена!"
        print_info "Сначала установите ноду (опция 1)"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    
    print_info "Запуск Unichain ноды..."
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "Нода успешно запущена!"
        echo ""
        sleep 3
        docker-compose ps
        echo ""
        print_info "Нода синхронизируется с сетью. Это может занять время."
        print_info "Используйте опцию 4 для проверки синхронизации"
    else
        print_error "Ошибка при запуске ноды"
        print_info "Проверьте логи: cd $INSTALL_DIR && docker-compose logs"
        return 1
    fi
}

# Остановка ноды
stop_node() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Нода не установлена!"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    
    print_info "Остановка Unichain ноды..."
    docker-compose down
    
    if [ $? -eq 0 ]; then
        print_success "Нода успешно остановлена"
    else
        print_error "Ошибка при остановке ноды"
        return 1
    fi
}

# Проверка статуса ноды
check_node_status() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Нода не установлена!"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    
    echo ""
    print_info "Статус контейнеров:"
    echo ""
    docker-compose ps
    
    echo ""
    print_info "Проверка JSON-RPC эндпоинта..."
    echo ""
    
    # Тест подключения
    RESPONSE=$(curl -s -d '{"id":1,"jsonrpc":"2.0","method":"eth_blockNumber","params":[]}' \
        -H "Content-Type: application/json" http://localhost:8545)
    
    if [ -n "$RESPONSE" ]; then
        BLOCK_HEX=$(echo $RESPONSE | jq -r '.result' 2>/dev/null)
        if [ "$BLOCK_HEX" != "null" ] && [ -n "$BLOCK_HEX" ]; then
            BLOCK_NUM=$(printf "%d\n" $BLOCK_HEX 2>/dev/null)
            print_success "Нода отвечает! Текущий блок: $BLOCK_NUM"
        else
            print_warning "Нода отвечает, но еще не синхронизирована"
        fi
        echo ""
        print_info "Тестовая команда для проверки последнего блока:"
        echo 'curl -d '"'"'{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}'"'"' -H "Content-Type: application/json" http://localhost:8545'
    else
        print_warning "Нода не отвечает или еще не готова"
        print_info "Подождите несколько минут и попробуйте снова"
    fi
    echo ""
}

# Просмотр логов
view_logs() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Нода не установлена!"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    
    echo ""
    echo "Выберите контейнер для просмотра логов:"
    echo ""
    echo "  1) execution-client (Geth)"
    echo "  2) op-node (OP Stack)"
    echo "  3) Все логи"
    echo "  0) Назад"
    echo ""
    read -p "Ваш выбор: " log_choice
    
    case $log_choice in
        1)
            print_info "Логи execution-client (Ctrl+C для выхода):"
            docker logs -f unichain-node-execution-client-1
            ;;
        2)
            print_info "Логи op-node (Ctrl+C для выхода):"
            docker logs -f unichain-node-op-node-1
            ;;
        3)
            print_info "Все логи (Ctrl+C для выхода):"
            docker-compose logs -f
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Неверный выбор"
            ;;
    esac
}

# Показать nodekey (приватный ключ ноды)
show_nodekey() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Нода не установлена!"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    
    NODEKEY_FILE="geth-data/geth/nodekey"
    
    if [ -f "$NODEKEY_FILE" ]; then
        print_warning "⚠️  ВНИМАНИЕ! Это приватный ключ вашей ноды!"
        print_warning "Храните его в безопасности и никому не показывайте!"
        echo ""
        read -p "Показать Node Key? (yes/no): " CONFIRM
        
        if [ "$CONFIRM" == "yes" ]; then
            echo ""
            print_info "Node Key:"
            cat "$NODEKEY_FILE"
            echo ""
            echo ""
            print_info "Сохраните этот ключ в безопасном месте!"
        else
            print_info "Отменено"
        fi
    else
        print_error "Файл nodekey не найден"
        print_info "Возможно, нода еще не была запущена"
    fi
}

# Обновление ноды
update_node() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Нода не установлена!"
        return 1
    fi
    
    print_info "Обновление Unichain ноды..."
    
    cd "$INSTALL_DIR"
    
    # Остановка ноды
    print_info "Остановка ноды..."
    docker-compose down
    
    # Обновление репозитория
    print_info "Получение последних обновлений..."
    git pull origin main
    
    # Обновление Docker образов
    print_info "Обновление Docker образов..."
    docker-compose pull
    
    # Запуск ноды
    print_info "Запуск обновленной ноды..."
    docker-compose up -d
    
    print_success "Нода обновлена и запущена!"
}

# Удаление ноды
remove_node() {
    print_warning "⚠️  Это удалит ноду и все её данные!"
    read -p "Вы уверены? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        print_info "Отменено"
        return 0
    fi
    
    if [ -d "$INSTALL_DIR" ]; then
        print_info "Остановка ноды..."
        cd "$INSTALL_DIR"
        docker-compose down -v
        cd ~
        
        print_info "Удаление файлов..."
        rm -rf "$INSTALL_DIR"
        
        read -p "Удалить также данные ноды в geth-data? (y/n): " DELETE_DATA
        if [[ "$DELETE_DATA" == "y" || "$DELETE_DATA" == "Y" ]]; then
            rm -rf "$INSTALL_DIR/geth-data"
            print_success "Данные ноды удалены"
        fi
        
        print_success "Нода успешно удалена"
    else
        print_error "Нода не установлена"
    fi
}

# Показать информацию о ноде
show_node_info() {
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Нода не установлена!"
        return 1
    fi
    
    cd "$INSTALL_DIR"
    
    echo ""
    print_info "Информация о Unichain ноде:"
    echo ""
    
    echo -e "${CYAN}Директория:${NC} $INSTALL_DIR"
    
    # Определение сети
    if grep -v "^#" docker-compose.yml | grep -q ".env.mainnet" 2>/dev/null; then
        echo -e "${CYAN}Сеть:${NC} Mainnet"
    elif grep -v "^#" docker-compose.yml | grep -q ".env.sepolia" 2>/dev/null; then
        echo -e "${CYAN}Сеть:${NC} Sepolia (Testnet)"
    else
        echo -e "${CYAN}Сеть:${NC} Не настроена"
    fi
    
    # Размер данных
    if [ -d "geth-data" ]; then
        SIZE=$(du -sh geth-data 2>/dev/null | cut -f1)
        echo -e "${CYAN}Размер данных:${NC} $SIZE"
    fi
    
    echo ""
    echo -e "${CYAN}Эндпоинты:${NC}"
    echo "  JSON-RPC: http://localhost:8545"
    echo "  WebSocket: ws://localhost:8546"
    
    echo ""
}

# Главное меню
main_menu() {
    while true; do
        print_header
        echo "Выберите действие:"
        echo ""
        echo "  📦 Установка:"
        echo "    1) Установить Unichain ноду"
        echo ""
        echo "  🚀 Управление:"
        echo "    2) Запустить ноду"
        echo "    3) Остановить ноду"
        echo ""
        echo "  📊 Мониторинг:"
        echo "    4) Проверить статус ноды"
        echo "    5) Просмотреть логи"
        echo "    6) Показать информацию о ноде"
        echo ""
        echo "  🔧 Дополнительно:"
        echo "    7) Показать Node Key (приватный ключ)"
        echo "    8) Обновить ноду"
        echo "    9) Удалить ноду"
        echo ""
        echo "    0) Выход"
        echo ""
        read -p "Ваш выбор: " choice
        
        case $choice in
            1)
                install_unichain_node
                read -p "Нажмите Enter для продолжения..."
                ;;
            2)
                start_node
                read -p "Нажмите Enter для продолжения..."
                ;;
            3)
                stop_node
                read -p "Нажмите Enter для продолжения..."
                ;;
            4)
                check_node_status
                read -p "Нажмите Enter для продолжения..."
                ;;
            5)
                view_logs
                ;;
            6)
                show_node_info
                read -p "Нажмите Enter для продолжения..."
                ;;
            7)
                show_nodekey
                read -p "Нажмите Enter для продолжения..."
                ;;
            8)
                update_node
                read -p "Нажмите Enter для продолжения..."
                ;;
            9)
                remove_node
                read -p "Нажмите Enter для продолжения..."
                ;;
            0)
                print_info "Выход..."
                exit 0
                ;;
            *)
                print_error "Неверный выбор"
                sleep 2
                ;;
        esac
    done
}

# Запуск главного меню
main_menu
