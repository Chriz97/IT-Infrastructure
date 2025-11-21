#!/bin/bash
echo "=== SELinux Violation Test (Optimized) ==="

# 0. Ensure required services/packages are installed and running
sudo dnf install -y httpd setroubleshoot-server > /dev/null 2>&1
sudo systemctl start httpd
sudo systemctl start auditd
sudo systemctl start setroubleshootd

echo ""
echo "1. SELinux status:"
getenforce

echo ""
echo "2. Creating test file with wrong context..."
TEST_FILE="/var/www/html/selinux_test.txt"
echo "SELinux test content" | sudo tee $TEST_FILE > /dev/null
# Set the context to something httpd cannot read (var_log_t)
sudo chcon -t var_log_t $TEST_FILE

echo ""
echo "3. File context (should be var_log_t):"
ls -Z $TEST_FILE

echo ""
echo "4. Requesting file via httpd (triggering the violation)..."
# This request will be DENIED and logged by SELinux if Enforcing.
curl -s http://localhost/selinux_test.txt || echo "Access denied (Expected due to SELinux)"

echo ""
echo "5. Checking for AVC denial using ausearch..."
sleep 1
# Search for AVC denials where the target context was var_log_t
sudo ausearch -m AVC -ts recent --context httpd_t | tail -1

echo ""
echo "6. Checking for human-readable alert with sealert..."
# sealert gives the clearest, exam-friendly output
sudo sealert -a /var/log/audit/audit.log 2>/dev/null | head -10

echo ""
echo "7. Cleanup - restoring correct context..."
sudo restorecon -v $TEST_FILE

echo ""
echo "=== Done ==="
