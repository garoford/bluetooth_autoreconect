# Bluetooth AutoReconnect

Sistema automático de gestión y reconexión de dispositivos Bluetooth para Fedora Linux.

## ¿Qué hace?

Este sistema automatiza completamente la gestión de dispositivos Bluetooth, manteniendo registro de los últimos dispositivos conectados y reconectándolos automáticamente cuando es necesario.

### Funcionalidades principales:

- **Registro automático**: Guarda automáticamente el último dispositivo de cada tipo (teclado, mouse, audio) que se conecta via Bluetooth
- **Reconexión inteligente**: Cuando Bluetooth cambia de OFF a ON, reconecta automáticamente a los dispositivos registrados
- **Reconexión al inicio**: Si el sistema inicia con Bluetooth encendido, reconecta automáticamente a los dispositivos guardados
- **Manejo de conflictos de audio**: Espera a que PipeWire se estabilice antes de reconectar dispositivos de audio
- **Logging completo**: Registra todas las actividades en logs del sistema

## ¿Cómo funciona?

### Arquitectura del sistema:

1. **Tracker de dispositivos** (`bluetooth-device-tracker`):
   - Monitorea conexiones de dispositivos Bluetooth
   - Identifica el tipo de dispositivo (teclado, mouse, audio) basándose en UUIDs e iconos
   - Guarda solo el último dispositivo de cada tipo en `/var/lib/bluetooth-manager/last_devices.conf`

2. **Monitor de estados** (`bluetooth-monitor`):
   - Usa D-Bus para detectar cambios en el estado de Bluetooth (ON/OFF)
   - Detecta nuevas conexiones de dispositivos
   - Inicia reconexión automática cuando Bluetooth se enciende

3. **Reconector** (`bluetooth-reconnect`):
   - Conecta dispositivos en paralelo para mayor velocidad
   - Timeouts optimizados (8 segundos por dispositivo)
   - Reporta estado de cada intento de conexión

4. **Reconector de inicio** (`bluetooth-startup-reconnect`):
   - Se ejecuta al inicio del sistema si Bluetooth ya está encendido
   - Espera a que PipeWire se estabilice (soluciona desconexiones de audio)
   - Delay de 15 segundos para evitar conflictos con servicios del sistema

### Servicios systemd:

- `bluetooth-manager.service`: Servicio principal que ejecuta el monitor
- Se inicia automáticamente con el sistema
- Se reinicia automáticamente en caso de fallos

## Instalación

```bash
# Clonar o descargar los archivos
git clone https://github.com/garoford/bluetooth_autoreconect.git
cd bluetooth_autoreconect

# Ejecutar instalación
./install.sh
```

## Uso

El sistema funciona automáticamente una vez instalado. No requiere intervención manual.

### Comandos útiles:

```bash
# Ver dispositivos guardados actualmente
sudo /usr/local/bin/bluetooth-device-tracker list

# Ver logs en tiempo real
sudo tail -f /var/log/bluetooth-monitor.log

# Estado del servicio
sudo systemctl status bluetooth-manager.service

# Reiniciar el servicio si es necesario
sudo systemctl restart bluetooth-manager.service
```

## Desinstalación

```bash
./delete.sh
```

Este comando elimina completamente todos los archivos, servicios y configuraciones creadas por el sistema.

## Archivos del sistema

### Scripts principales:
- `/usr/local/bin/bluetooth-device-tracker` - Rastreador de dispositivos
- `/usr/local/bin/bluetooth-monitor` - Monitor de estados Bluetooth
- `/usr/local/bin/bluetooth-reconnect` - Reconector rápido
- `/usr/local/bin/bluetooth-startup-reconnect` - Reconector de inicio

### Configuración y datos:
- `/var/lib/bluetooth-manager/last_devices.conf` - Dispositivos guardados
- `/var/log/bluetooth-monitor.log` - Logs del sistema
- `/etc/systemd/system/bluetooth-manager.service` - Servicio systemd

## Optimizaciones implementadas

### Velocidad de reconexión:
- **Conexiones paralelas**: Los dispositivos se conectan simultáneamente
- **Detección rápida**: 0.5 segundos para detectar cambios de estado
- **Timeouts optimizados**: 8 segundos máximo por dispositivo
- **Resultado**: Reconexión en ~2-9 segundos (vs ~15+ segundos anteriormente)

### Estabilidad del sistema:
- **Manejo de PipeWire**: Espera automática para evitar desconexiones de audio
- **Prevención de duplicados**: Locks para evitar múltiples instancias ejecutándose
- **Reinicio automático**: El servicio se reinicia en caso de fallos

## Sistema de prueba

Este sistema fue desarrollado y probado en:

### Software:
- **OS**: Fedora Linux 43 (Workstation Edition)
- **Kernel**: 6.17.7-300.fc43.x86_64
- **Systemd**: 258.1-1.fc43
- **BlueZ**: 5.84
- **Audio**: PipeWire

### Dispositivos Bluetooth probados:
- **Teclado**: POP Icon Keys (DA:33:FE:D9:14:F8)
- **Audio**: Sound Blaster GS3 (00:02:3C:BD:5D:03)
- **Audio**: Redmi Buds 6 Pro (00:BB:43:5E:27:8C)

### Escenarios de prueba:
✅ Reconexión automática al encender Bluetooth  
✅ Reconexión al inicio del sistema  
✅ Manejo de desconexiones durante inicio de sesión  
✅ Tracking automático de nuevos dispositivos  
✅ Funcionamiento estable durante múltiples ciclos ON/OFF  

## Requisitos del sistema

- Fedora Linux (desarrollado en versión 43)
- BlueZ instalado y funcionando
- Systemd
- D-Bus
- Permisos sudo para instalación

## Solución de problemas

### Si los dispositivos no se reconectan:
1. Verificar que estén emparejados: `bluetoothctl devices`
2. Revisar logs: `sudo tail -20 /var/log/bluetooth-monitor.log`
3. Verificar servicio: `sudo systemctl status bluetooth-manager.service`

### Si el audio se desconecta después del login:
El sistema ya incluye una solución automática esperando a que PipeWire se estabilice. Si persiste el problema, puede requerir ajustar el delay en el script de startup.

## Contribuir

1. Fork del repositorio
2. Crear branch para feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit de cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. Push al branch (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## Licencia

Este proyecto es de código abierto. Puedes usarlo, modificarlo y distribuirlo libremente.

---
*Desarrollado y probado en Fedora 43*
