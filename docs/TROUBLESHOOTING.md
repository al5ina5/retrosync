# RetroSync Troubleshooting Guide

**Last Updated:** January 30, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [Common Issues](#common-issues)
2. [Error Codes](#error-codes)
3. [Connection Problems](#connection-problems)
4. [Device-Specific Issues](#device-specific-issues)
5. [Sync Problems](#sync-problems)
6. [Getting Help](#getting-help)

---

## Common Issues

### Issue: "Command not found" (pip install)

**Error:**
```bash
$ retrosync
bash: retrosync: command not found
```

**Solutions:**

1. **Check Python installation:**
   ```bash
   python3 --version  # Should be 3.9+
   pip3 --version
   ```

2. **Reinstall RetroSync:**
   ```bash
   pip3 uninstall retrosync
   pip3 install --force retrosync
   ```

3. **Add to PATH (Linux/macOS):**
   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **Windows - Ensure Python in PATH:**
   - Re-run Python installer
   - ✓ Add Python to PATH option checked

---

### Issue: "Connection refused"

**Error:**
```
requests.exceptions.ConnectionError: HTTPConnectionPool(host='localhost', port=3000): Max retries exceeded
```

**Solutions:**

1. **Verify server is running:**
   ```bash
   # On server
   curl http://localhost:3000/api/health
   ```

2. **Check server URL in config:**
   ```bash
   cat ~/.retrosync/config.json
   # Verify "api_url" is correct
   ```

3. **Check firewall:**
   ```bash
   # Linux
   sudo ufw status
   # Allow port 3000 if blocked
   ```

4. **Test network connectivity:**
   ```bash
   ping YOUR-SERVER-IP
   curl http://YOUR-SERVER-IP:3000
   ```

---

### Issue: "Device Offline" in Dashboard

**Error:** Dashboard shows device as offline despite daemon running.

**Solutions:**

1. **Check daemon is running:**
   ```bash
   retrosync status
   # If stopped: retrosync daemon
   ```

2. **Verify API key:**
   ```bash
   cat ~/.retrosync/config.json | grep api_key
   ```

3. **Check heartbeat:**
   ```bash
   tail -f ~/.retrosync/retrosync.log
   # Should see "Heartbeat sent" every 30 seconds
   ```

4. **Restart daemon:**
   ```bash
   retrosync stop
   retrosync daemon
   ```

---

### Issue: "No saves found"

**Error:** RetroSync runs but no save files are detected.

**Solutions:**

1. **Check save directory exists:**
   ```bash
   ls -la /mnt/SDCARD/Saves/
   ```

2. **Verify configuration:**
   ```bash
   retrosync config show
   # Check "save_directory" path
   ```

3. **List detected saves:**
   ```bash
   retrosync list
   ```

4. **Add custom watch path:**
   ```bash
   retrosync config add_watch_path /path/to/your/saves
   ```

5. **Check file extensions:**
   - RetroSync syncs: `.srm`, `.sav`, `.state`, `.mpk`
   - Other files are ignored

---

### Issue: "Upload failed"

**Error:** File uploads fail with timeout or network error.

**Solutions:**

1. **Check server storage:**
   ```bash
   # On server
   df -h /data
   ```

2. **Verify S3/MinIO is running:**
   ```bash
   docker ps | grep minio
   ```

3. **Check network speed:**
   ```bash
   # Test upload speed
   curl -T large-file http://YOUR-SERVER:9000/
   ```

4. **Reduce file size:**
   - Some save states can be large
   - Consider excluding large state files

---

## Error Codes

### Authentication Errors

| Code | Message | Solution |
|------|---------|----------|
| `ERR_AUTH_FAIL` | Invalid credentials | Check email/password |
| `ERR_TOKEN_EXPIRED` | JWT expired | Re-login |
| `ERR_NO_PERMISSION` | Access denied | Check device pairing |
| `ERR_API_KEY_INVALID` | Invalid API key | Re-pair device |

**Recovery:**
```bash
retrosync logout
retrosync setup
# Re-pair device
```

### Connection Errors

| Code | Message | Solution |
|------|---------|----------|
| `ERR_CONN_REFUSED` | Server not running | Start server |
| `ERR_CONN_TIMEOUT` | Connection timeout | Check network/firewall |
| `ERR_DNS_FAIL` | Cannot resolve host | Check server URL |
| `ERR_SSL_CERT` | SSL certificate error | Check certificate |

**Recovery:**
```bash
# Verify server URL
retrosync config show | grep api_url

# Test connection
curl http://YOUR-SERVER:3000/api/health
```

### Sync Errors

| Code | Message | Solution |
|------|---------|----------|
| `ERR_UPLOAD_FAIL` | Upload failed | Check server storage |
| `ERR_DOWNLOAD_FAIL` | Download failed | Check network |
| `ERR_FILE_NOT_FOUND` | File missing | Check file path |
| `ERR_CONFLICT_DETECTED` | Sync conflict | Manual resolution |
| `ERR_QUOTA_EXCEEDED` | Storage full | Delete old saves |

**Recovery (Conflict):**
```bash
# Download both versions
retrosync download GAME.srm
retrosync download GAME-DeviceB.srm

# Rename and keep both
mv GAME.srm GAME-DeviceA.srm

# Upload renamed file
retrosync upload GAME-DeviceA.srm
```

### File Errors

| Code | Message | Solution |
|------|---------|----------|
| `ERR_FILE_TOO_LARGE` | Exceeds size limit | Split or exclude |
| `ERR_FILE_READ` | Cannot read file | Check permissions |
| `ERR_FILE_WRITE` | Cannot write file | Check disk space |
| `ERR_PERMISSION_DENIED` | Access denied | chmod files |

---

## Connection Problems

### WiFi Not Connecting (Handhelds)

1. **Verify WiFi settings:**
   - Settings → WiFi → Select network
   - Enter correct password

2. **Check IP address:**
   ```bash
   ifconfig wlan0
   # Note IP address for server config
   ```

3. **Test internet:**
   ```bash
   ping 8.8.8.8
   ```

4. **Restart network:**
   ```bash
   systemctl restart networking
   ```

### Server Not Accessible

1. **Check server is running:**
   ```bash
   # On server
   docker ps | grep -E "retrosync|minio"
   ```

2. **Check ports:**
   ```bash
   # On server
   netstat -tlnp | grep -E "3000|9000"
   ```

3. **Check logs:**
   ```bash
   docker-compose logs -f
   ```

4. **Firewall rules:**
   ```bash
   # Linux - allow ports
   sudo ufw allow 3000/tcp
   sudo ufw allow 9000/tcp
   sudo ufw reload
   ```

### MinIO/S3 Issues

1. **Check MinIO console:**
   - http://YOUR-SERVER:9001
   - Login: minioadmin/minioadmin

2. **Verify bucket exists:**
   ```bash
   # In MinIO console or mc
   mc ls myminio/ | grep retrosync-saves
   ```

3. **Check credentials:**
   ```bash
   # In config
   cat ~/.retrosync/config.json | grep -A5 s3
   ```

---

## Device-Specific Issues

### muOS (Anbernic RG35XX+)

#### Issue: Python not installed

**Solution:**
```bash
# SSH into device
ssh root@DEVICE-IP

# Install Python
opkg update
opkg install python3
```

#### Issue: SSH connection refused

**Solution:**
1. Enable SSH in muOS:
   - Settings → System → SSH → Enable
2. Check IP address:
   - Settings → Network → WiFi → IP Address

#### Issue: Saves not detected

**Solution:**
```bash
# Check paths
ls /mnt/SDCARD/RetroArch/saves/
ls /mnt/SDCARD/Saves/

# Verify RetroSync config
cat /mnt/SDCARD/RetroSync/config.json
```

### Spruce OS (Miyoo Flip)

#### Issue: "Python not installed" message

**Solution:**
- Install Python 3 for Spruce OS (see Installation guide)
- OR use LÖVE app instead
- OR use shell client (experimental)

#### Issue: Touchscreen not working

**Solution:**
- RetroSync doesn't require touchscreen
- Use D-pad and A/B buttons
- A = Confirm, B = Cancel/Back

#### Issue: App crashes on launch

**Solution:**
1. Check free space:
   ```bash
   df -h
   ```
2. Clear cache:
   ```bash
   rm -rf /tmp/retroarch-*
   ```
3. Reinstall app:
   - Delete /mnt/SDCARD/App/RetroSync
   - Re-copy files

### PC (Windows/macOS/Linux)

#### Issue: Windows - Python not found

**Solution:**
1. Download Python from python.org
2. ✓ Check "Add Python to PATH"
3. Restart terminal

#### Issue: macOS - Permission denied

**Solution:**
```bash
# Install for user only
pip3 install --user retrosync

# Or use virtual environment
python3 -m venv retrosync-env
source retrosync-env/bin/activate
pip install retrosync
```

#### Issue: Linux - Module not found

**Solution:**
```bash
# Install dependencies
sudo apt install python3-pip python3-dev

# Reinstall
pip3 install --force-reinstall retrosync
```

---

## Sync Problems

### Files Not Uploading

1. **Check file is save file:**
   ```bash
   # Must have valid extension
   ls *.srm *.sav *.state
   ```

2. **Check file changed:**
   ```bash
   # RetroSync only uploads changed files
   stat YOUR_FILE.srm
   ```

3. **Force upload:**
   ```bash
   retrosync upload --force /path/to/file.srm
   ```

4. **Check logs:**
   ```bash
   tail -f ~/.retrosync/retrosync.log
   ```

### Files Not Downloading

1. **Check cloud has file:**
   - Login to dashboard
   - Check Saves section

2. **Check disk space:**
   ```bash
   df -h
   ```

3. **Force download:**
   ```bash
   retrosync download filename.srm
   ```

4. **Verify sync directory:**
   ```bash
   retrosync config show | grep save_directory
   ```

### Sync Too Slow

1. **Check network speed:**
   ```bash
   speedtest-cli
   ```

2. **Reduce sync frequency:**
   ```bash
   retrosync config set poll_interval 60  # Default is 30
   ```

3. **Exclude large files:**
   ```bash
   retrosync config add_exclusion "*.state"
   ```

### Incomplete Sync After Crash

1. **Stop daemon:**
   ```bash
   retrosync stop
   ```

2. **Clear locks:**
   ```bash
   rm -f ~/.retrosync/*.lock
   ```

3. **Restart:**
   ```bash
   retrosync daemon
   ```

4. **Force re-sync:**
   ```bash
   retrosync sync --force
   ```

---

## Getting Help

### Before Asking for Help

1. **Check logs:**
   ```bash
   tail -n 100 ~/.retrosync/retrosync.log
   ```

2. **Gather system info:**
   ```bash
   # Python version
   python3 --version

   # RetroSync version
   retrosync --version

   # Config (remove sensitive data)
   cat ~/.retrosync/config.json
   ```

3. **Try basic fixes:**
   - Restart daemon
   - Reinstall package
   - Reboot device

### Contact Support

1. **GitHub Issues:** Report bugs
   - https://github.com/al5ina5/retrosync/issues

2. **Discord Community:** Get help
   - Join RetroSync Discord server

3. **Email Support:** Pro tier only
   - support@retrosync.example.com

### Information to Include

When asking for help, include:

```
RetroSync Version: X.X.X
Python Version: X.X.X
Operating System: XXX
Server URL: http://xxx.xxx.xxx.xxx:3000

Error Message:
[Your error message here]

Steps to Reproduce:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Logs:
[Relevant log lines]
```

---

## Related Documentation

- [Installation Guide](INSTALLATION.md)
- [Usage Guide](USAGE.md)
- [Compatibility List](COMPATIBILITY.md)
- [Developer Guide](DEVELOPER.md)
