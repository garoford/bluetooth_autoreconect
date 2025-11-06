# Bluetooth AutoReconnect

*Bluetooth que funciona como en Windows/macOS - se conecta automáticamente*

**Keywords:** `bluetooth auto connect linux` `fedora bluetooth like windows` `airpods linux auto connect` `migrar windows linux bluetooth`

## ¿Qué hace?

Conecta automáticamente tus dispositivos Bluetooth (auriculares, teclado, mouse) cuando enciendes tu PC, exactamente como en Windows/macOS.

**Antes:** Abrir configuraciones → buscar dispositivo → hacer clic "conectar" cada vez  
**Después:** Encender PC → todo se conecta solo

## Instalación

```bash
git clone https://github.com/garoford/bluetooth_autoreconect.git
cd bluetooth_autoreconect
./install.sh
```

## Uso

Funciona automáticamente. Una vez instalado, tus dispositivos se conectarán solos.

### Comandos útiles:
```bash
# Ver dispositivos guardados
sudo /usr/local/bin/bluetooth-device-tracker list

# Ver logs
sudo tail -f /var/log/bluetooth-monitor.log

# Estado del servicio
sudo systemctl status bluetooth-manager.service
```

## Desinstalar

```bash
./delete.sh
```

## Cómo funciona

1. Guarda el último teclado, mouse y dispositivo de audio que conectas
2. Cuando Bluetooth se enciende, reconecta automáticamente esos dispositivos
3. Al iniciar el PC, espera a que el sistema esté listo y reconecta todo

## Sistema probado

- **Hardware:** Gigabyte B360M GAMING HD, Intel i5-8400, 16GB RAM
- **OS:** Fedora 43, Kernel 6.17.7, PipeWire
- **Dispositivos:** POP Icon Keys, Sound Blaster GS3, Redmi Buds 6 Pro

## Solución de problemas

**Dispositivos no se reconectan:**
1. `bluetoothctl devices` - verificar que estén emparejados
2. `sudo tail -20 /var/log/bluetooth-monitor.log` - revisar logs
3. `sudo systemctl restart bluetooth-manager.service` - reiniciar servicio
