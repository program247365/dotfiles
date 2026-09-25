import subprocess, time

bear_running = subprocess.run(['pgrep', '-x', 'Bear'], capture_output=True).returncode == 0
subprocess.run(['open', '-g', '-a', 'Bear'])  # background launch; no-op if already running
if not bear_running:
    print('Bear was not running — launched it; waiting 60s for CloudKit to pull remote changes')
    time.sleep(60)
else:
    print('Bear already running — waiting 15s for any in-flight sync to land')
    time.sleep(15)
