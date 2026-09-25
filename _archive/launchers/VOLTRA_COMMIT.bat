@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA COMMIT
git add lib _run_server.bat VOLTRA_HEALTH.bat VOLTRA_DEV.bat VOLTRA_RUN.bat VOLTRA_RESTART_SERVER.bat > _logs\50_commit.log 2>&1
git commit -m "Home: live Apple Watch summary from /health/summary (typed models, explicit states)" >> _logs\50_commit.log 2>&1
git log --oneline -3 >> _logs\50_commit.log 2>&1
echo DONE > _logs\_commit_done.txt
timeout /t 5 /nobreak > nul
