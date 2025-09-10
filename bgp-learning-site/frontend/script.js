class BGPLearningApp {
    constructor() {
        this.apiBase = '/api';
        this.simulationState = {
            routers: {},
            currentStep: 0,
            totalSteps: 0,
            isRunning: false
        };
        this.initializeApp();
    }

    async initializeApp() {
        this.setupEventListeners();
        await this.loadFirstLesson();
        await this.resetSimulation();
        this.createNetworkVisualization();
    }

    setupEventListeners() {
        // Выполнение команды
        document.getElementById('execute-btn').addEventListener('click', () => {
            this.executeCommand();
        });

        // Enter в поле команды
        document.getElementById('command-input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.executeCommand();
            }
        });

        // Контроль симуляции
        document.getElementById('step-btn').addEventListener('click', () => {
            this.nextStep();
        });

        document.getElementById('pause-btn').addEventListener('click', () => {
            this.pauseSimulation();
        });

        document.getElementById('reset-btn').addEventListener('click', () => {
            this.resetSimulation();
        });
    }

    async loadFirstLesson() {
        try {
            const response = await fetch(`${this.apiBase}/lessons/first`);
            const lesson = await response.json();
            
            const instructionsElement = document.getElementById('lesson-instructions');
            instructionsElement.innerHTML = `
                <p><strong>${lesson.description}</strong></p>
                <ol>
                    ${lesson.instructions.map(instruction => `<li>${instruction}</li>`).join('')}
                </ol>
                <div class="example-commands">
                    <h4>Примеры команд:</h4>
                    <ul>
                        ${lesson.commands.map(cmd => `<li><code>${cmd}</code></li>`).join('')}
                    </ul>
                </div>
            `;
        } catch (error) {
            console.error('Error loading lesson:', error);
            this.showOutput('Ошибка загрузки урока', 'error');
        }
    }

    async executeCommand() {
        const commandInput = document.getElementById('command-input');
        const routerSelect = document.getElementById('router-select');
        const command = commandInput.value.trim();
        
        if (!command) {
            this.showOutput('Введите команду', 'error');
            return;
        }

        const router = routerSelect.value;
        
        try {
            this.showOutput(`${router}# ${command}`, 'command');
            
            const response = await fetch(`${this.apiBase}/command/execute`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    command: command,
                    router: router
                })
            });

            const result = await response.json();
            
            if (result.status === 'success') {
                this.showOutput(result.message, 'success');
                commandInput.value = '';
                
                // Обновление состояния симуляции
                await this.updateSimulationState();
                
                // Включение кнопки "Следующий шаг" если есть шаги
                if (this.simulationState.totalSteps > this.simulationState.currentStep) {
                    document.getElementById('step-btn').disabled = false;
                }
            } else {
                this.showOutput(result.message, 'error');
            }
        } catch (error) {
            console.error('Error executing command:', error);
            this.showOutput('Ошибка выполнения команды', 'error');
        }
    }

    async nextStep() {
        try {
            const response = await fetch(`${this.apiBase}/simulation/step`, {
                method: 'POST'
            });

            const result = await response.json();
            
            if (result.status === 'success') {
                // Обновление состояния
                this.simulationState = {
                    routers: result.routers,
                    currentStep: result.current_step,
                    totalSteps: result.total_steps,
                    isRunning: true
                };
                
                // Показ шага
                this.showOutput(`Шаг ${result.current_step}: ${result.step.description}`, 'info');
                
                // Анимация если нужна
                if (result.step.animation) {
                    await this.playAnimation(result.step);
                }
                
                // Обновление интерфейса
                this.updateRouterStatus();
                this.updateStepCounter();
                
                // Проверка завершения
                if (result.current_step >= result.total_steps) {
                    document.getElementById('step-btn').disabled = true;
                    this.showOutput('Симуляция завершена!', 'success');
                }
                
            } else if (result.status === 'completed') {
                this.showOutput(result.message, 'info');
                document.getElementById('step-btn').disabled = true;
            } else {
                this.showOutput(result.message, 'error');
            }
        } catch (error) {
            console.error('Error in simulation step:', error);
            this.showOutput('Ошибка выполнения шага', 'error');
        }
    }

    async playAnimation(step) {
        if (step.animation === 'packet_flow') {
            await this.animatePacket(step.from, step.to, step.packet_type);
        } else if (step.animation === 'connection_established') {
            this.highlightConnection();
        }
    }

    async animatePacket(fromRouter, toRouter, packetType) {
        const fromElement = document.querySelector(`[data-router="${fromRouter}"]`);
        const toElement = document.querySelector(`[data-router="${toRouter}"]`);
        
        if (!fromElement || !toElement) return;
        
        // Создание пакета
        const packet = document.createElement('div');
        packet.className = 'packet';
        packet.title = `BGP ${packetType} packet`;
        
        const canvas = document.getElementById('network-canvas');
        canvas.appendChild(packet);
        
        // Начальная позиция
        const fromRect = fromElement.getBoundingClientRect();
        const canvasRect = canvas.getBoundingClientRect();
        const startX = fromRect.left - canvasRect.left + fromRect.width / 2;
        const startY = fromRect.top - canvasRect.top + fromRect.height / 2;
        
        // Конечная позиция
        const toRect = toElement.getBoundingClientRect();
        const endX = toRect.left - canvasRect.left + toRect.width / 2;
        const endY = toRect.top - canvasRect.top + toRect.height / 2;
        
        // Установка начальной позиции
        packet.style.left = startX + 'px';
        packet.style.top = startY + 'px';
        
        // Анимация
        return new Promise(resolve => {
            packet.style.transition = 'all 1.5s ease-in-out';
            
            setTimeout(() => {
                packet.style.left = endX + 'px';
                packet.style.top = endY + 'px';
            }, 100);
            
            setTimeout(() => {
                packet.remove();
                resolve();
            }, 1600);
        });
    }

    highlightConnection() {
        const connectionLine = document.querySelector('.connection-line');
        if (connectionLine) {
            connectionLine.classList.add('active');
            
            // Подсветка роутеров
            document.querySelectorAll('.router').forEach(router => {
                router.classList.add('active');
            });
        }
    }

    pauseSimulation() {
        this.simulationState.isRunning = false;
        document.getElementById('pause-btn').disabled = true;
        document.getElementById('step-btn').disabled = false;
        this.showOutput('Симуляция приостановлена', 'info');
    }

    async resetSimulation() {
        try {
            const response = await fetch(`${this.apiBase}/simulation/reset`, {
                method: 'POST'
            });

            const result = await response.json();
            
            if (result.status === 'success') {
                this.simulationState = {
                    routers: result.routers,
                    currentStep: 0,
                    totalSteps: 0,
                    isRunning: false
                };
                
                // Сброс интерфейса
                document.getElementById('step-btn').disabled = true;
                document.getElementById('pause-btn').disabled = true;
                document.getElementById('command-input').value = '';
                
                // Очистка вывода
                document.getElementById('command-output').innerHTML = '<p>Симуляция сброшена. Готов к вводу команд...</p>';
                
                // Обновление статуса
                this.updateRouterStatus();
                this.updateStepCounter();
                
                // Сброс визуализации
                this.resetVisualization();
                
                this.showOutput('Симуляция сброшена', 'info');
            }
        } catch (error) {
            console.error('Error resetting simulation:', error);
            this.showOutput('Ошибка сброса симуляции', 'error');
        }
    }

    async updateSimulationState() {
        try {
            const response = await fetch(`${this.apiBase}/simulation/state`);
            const state = await response.json();
            
            this.simulationState = state;
            this.updateRouterStatus();
            this.updateStepCounter();
        } catch (error) {
            console.error('Error updating simulation state:', error);
        }
    }

    updateRouterStatus() {
        Object.keys(this.simulationState.routers).forEach(routerId => {
            const router = this.simulationState.routers[routerId];
            const statusElement = document.getElementById(`${routerId.toLowerCase()}-status`);
            
            if (statusElement) {
                const stateSpan = statusElement.querySelector('.bgp-state');
                if (stateSpan) {
                    stateSpan.textContent = router.bgp_state;
                    stateSpan.className = `bgp-state ${router.bgp_state.toLowerCase()}`;
                }
            }
        });
    }

    updateStepCounter() {
        document.getElementById('step-counter').textContent = 
            `Шаг: ${this.simulationState.currentStep} / ${this.simulationState.totalSteps}`;
    }

    createNetworkVisualization() {
        const canvas = document.getElementById('network-canvas');
        canvas.innerHTML = '';
        
        // Создание роутеров
        const r1 = this.createRouter('R1', 150, 200, 'AS 65001');
        const r2 = this.createRouter('R2', 450, 200, 'AS 65002');
        
        canvas.appendChild(r1);
        canvas.appendChild(r2);
        
        // Создание линии соединения
        const connectionLine = document.createElement('div');
        connectionLine.className = 'connection-line';
        connectionLine.style.left = '190px';
        connectionLine.style.top = '235px';
        connectionLine.style.width = '220px';
        canvas.appendChild(connectionLine);
    }

    createRouter(id, x, y, asLabel) {
        const router = document.createElement('div');
        router.className = 'router';
        router.setAttribute('data-router', id);
        router.style.left = x + 'px';
        router.style.top = y + 'px';
        router.textContent = id;
        
        const label = document.createElement('div');
        label.className = 'router-label';
        label.textContent = asLabel;
        router.appendChild(label);
        
        return router;
    }

    resetVisualization() {
        // Удаление классов активности
        document.querySelectorAll('.router').forEach(router => {
            router.classList.remove('active');
        });
        
        document.querySelectorAll('.connection-line').forEach(line => {
            line.classList.remove('active');
        });
        
        // Удаление пакетов
        document.querySelectorAll('.packet').forEach(packet => {
            packet.remove();
        });
    }

    showOutput(message, type = 'info') {
        const output = document.getElementById('command-output');
        const messageElement = document.createElement('div');
        messageElement.className = `output-message ${type}`;
        
        const timestamp = new Date().toLocaleTimeString();
        messageElement.innerHTML = `<span class="timestamp">[${timestamp}]</span> ${message}`;
        
        output.appendChild(messageElement);
        output.scrollTop = output.scrollHeight;
        
        // Ограничение количества сообщений
        while (output.children.length > 50) {
            output.removeChild(output.firstChild);
        }
    }
}

// Стили для сообщений вывода
const outputStyles = `
    .output-message {
        margin: 5px 0;
        padding: 5px;
        border-radius: 3px;
    }
    
    .output-message.command {
        background: #e9ecef;
        font-weight: bold;
    }
    
    .output-message.success {
        background: #d4edda;
        color: #155724;
    }
    
    .output-message.error {
        background: #f8d7da;
        color: #721c24;
    }
    
    .output-message.info {
        background: #d1ecf1;
        color: #0c5460;
    }
    
    .timestamp {
        color: #6c757d;
        font-size: 11px;
    }
`;

// Добавление стилей
const style = document.createElement('style');
style.textContent = outputStyles;
document.head.appendChild(style);

// Инициализация приложения при загрузке страницы
document.addEventListener('DOMContentLoaded', () => {
    new BGPLearningApp();
});