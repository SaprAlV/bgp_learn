from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
import time
import re

app = Flask(__name__)
CORS(app)

# Настройка логирования
import os
log_file = '/var/log/bgp-learning.log'

# Создание обработчиков логов с проверкой прав
handlers = [logging.StreamHandler()]

# Добавляем файловый обработчик только если можем писать в файл
try:
    if os.path.exists(log_file):
        # Проверяем, можем ли мы писать в существующий файл
        if os.access(log_file, os.W_OK):
            handlers.append(logging.FileHandler(log_file))
    else:
        # Пытаемся создать файл
        log_dir = os.path.dirname(log_file)
        if os.access(log_dir, os.W_OK):
            handlers.append(logging.FileHandler(log_file))
except (OSError, PermissionError):
    # Если не можем работать с файлом, используем только консольный вывод
    pass

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=handlers
)
logger = logging.getLogger(__name__)

# Начальное состояние симуляции
class BGPSimulation:
    def __init__(self):
        self.reset()
    
    def reset(self):
        self.routers = {
            'R1': {
                'id': 'R1',
                'ip': '192.168.1.1',
                'as': 65001,
                'neighbors': {},
                'bgp_state': 'Idle',
                'position': {'x': 150, 'y': 200}
            },
            'R2': {
                'id': 'R2', 
                'ip': '192.168.1.2',
                'as': 65002,
                'neighbors': {},
                'bgp_state': 'Idle',
                'position': {'x': 450, 'y': 200}
            }
        }
        self.simulation_steps = []
        self.current_step = 0
        self.is_running = False

# Глобальный объект симуляции
simulation = BGPSimulation()

@app.route('/api/simulation/reset', methods=['POST'])
def reset_simulation():
    """Сброс симуляции в начальное состояние"""
    try:
        simulation.reset()
        logger.info("Simulation reset")
        return jsonify({
            'status': 'success',
            'message': 'Симуляция сброшена',
            'routers': simulation.routers
        })
    except Exception as e:
        logger.error(f"Error resetting simulation: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/simulation/state', methods=['GET'])
def get_simulation_state():
    """Получение текущего состояния симуляции"""
    return jsonify({
        'routers': simulation.routers,
        'current_step': simulation.current_step,
        'total_steps': len(simulation.simulation_steps),
        'is_running': simulation.is_running
    })

@app.route('/api/command/execute', methods=['POST'])
def execute_command():
    """Выполнение BGP команды"""
    try:
        data = request.get_json()
        command = data.get('command', '').strip()
        router_id = data.get('router', 'R1')
        
        logger.info(f"Executing command on {router_id}: {command}")
        
        # Парсинг команды
        result = parse_bgp_command(command, router_id)
        
        if result['status'] == 'success':
            # Генерация шагов симуляции
            steps = generate_simulation_steps(result['action'], router_id)
            simulation.simulation_steps.extend(steps)
            
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error executing command: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/simulation/step', methods=['POST'])
def simulation_step():
    """Выполнение одного шага симуляции"""
    try:
        if simulation.current_step >= len(simulation.simulation_steps):
            return jsonify({
                'status': 'completed',
                'message': 'Все шаги выполнены'
            })
        
        step = simulation.simulation_steps[simulation.current_step]
        
        # Выполнение шага
        execute_simulation_step(step)
        simulation.current_step += 1
        
        logger.info(f"Executed step {simulation.current_step}: {step['description']}")
        
        return jsonify({
            'status': 'success',
            'step': step,
            'routers': simulation.routers,
            'current_step': simulation.current_step,
            'total_steps': len(simulation.simulation_steps)
        })
        
    except Exception as e:
        logger.error(f"Error in simulation step: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

def parse_bgp_command(command, router_id):
    """Парсинг BGP команд"""
    command = command.lower().strip()
    
    # neighbor IP remote-as AS
    neighbor_pattern = r'neighbor\s+(\d+\.\d+\.\d+\.\d+)\s+remote-as\s+(\d+)'
    match = re.match(neighbor_pattern, command)
    if match:
        neighbor_ip = match.group(1)
        remote_as = int(match.group(2))
        
        return {
            'status': 'success',
            'action': 'configure_neighbor',
            'data': {
                'neighbor_ip': neighbor_ip,
                'remote_as': remote_as
            },
            'message': f'Настройка соседа {neighbor_ip} AS {remote_as}'
        }
    
    # neighbor IP activate
    activate_pattern = r'neighbor\s+(\d+\.\d+\.\d+\.\d+)\s+activate'
    match = re.match(activate_pattern, command)
    if match:
        neighbor_ip = match.group(1)
        
        return {
            'status': 'success',
            'action': 'activate_neighbor',
            'data': {
                'neighbor_ip': neighbor_ip
            },
            'message': f'Активация соседа {neighbor_ip}'
        }
    
    return {
        'status': 'error',
        'message': 'Неизвестная команда. Используйте: neighbor IP remote-as AS или neighbor IP activate'
    }

def generate_simulation_steps(action, router_id):
    """Генерация шагов симуляции для действия"""
    steps = []
    
    if action == 'configure_neighbor':
        steps.append({
            'type': 'config',
            'router': router_id,
            'description': 'Настройка BGP соседа',
            'animation': None
        })
        
    elif action == 'activate_neighbor':
        # Процесс установления соседства
        steps.extend([
            {
                'type': 'send_packet',
                'from': router_id,
                'to': 'R2' if router_id == 'R1' else 'R1',
                'packet_type': 'OPEN',
                'description': 'Отправка BGP OPEN сообщения',
                'animation': 'packet_flow'
            },
            {
                'type': 'state_change',
                'router': router_id,
                'new_state': 'OpenSent',
                'description': 'Переход в состояние OpenSent',
                'animation': None
            },
            {
                'type': 'receive_packet',
                'from': 'R2' if router_id == 'R1' else 'R1',
                'to': router_id,
                'packet_type': 'OPEN',
                'description': 'Получение BGP OPEN сообщения',
                'animation': 'packet_flow'
            },
            {
                'type': 'send_packet',
                'from': router_id,
                'to': 'R2' if router_id == 'R1' else 'R1',
                'packet_type': 'KEEPALIVE',
                'description': 'Отправка KEEPALIVE сообщения',
                'animation': 'packet_flow'
            },
            {
                'type': 'state_change',
                'router': router_id,
                'new_state': 'Established',
                'description': 'BGP соседство установлено',
                'animation': 'connection_established'
            }
        ])
    
    return steps

def execute_simulation_step(step):
    """Выполнение одного шага симуляции"""
    if step['type'] == 'config':
        # Обновление конфигурации
        pass
        
    elif step['type'] == 'state_change':
        router_id = step['router']
        new_state = step['new_state']
        simulation.routers[router_id]['bgp_state'] = new_state
        
    elif step['type'] == 'send_packet' or step['type'] == 'receive_packet':
        # Логирование пакетов
        pass

@app.route('/api/lessons/first', methods=['GET'])
def get_first_lesson():
    """Получение данных первого урока"""
    return jsonify({
        'title': 'Урок 1: Установление BGP соседства',
        'description': 'В этом уроке вы изучите процесс установления BGP соседства между двумя маршрутизаторами.',
        'instructions': [
            '1. Настройте BGP соседа командой: neighbor 192.168.1.2 remote-as 65002',
            '2. Активируйте соседа командой: neighbor 192.168.1.2 activate',
            '3. Наблюдайте за процессом установления соседства'
        ],
        'commands': [
            'neighbor 192.168.1.2 remote-as 65002',
            'neighbor 192.168.1.2 activate'
        ]
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=True)