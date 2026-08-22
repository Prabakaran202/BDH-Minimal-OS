#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/mount.h> 
#include <sys/stat.h> // mkdir() ஃபங்ஷனுக்காக சேர்க்கப்பட்டுள்ளது

#define MAX_CMD_LEN 100
#define MAX_ARGS 10

int main() {
    char command[MAX_CMD_LEN];
    char *args[MAX_ARGS];

    // --- AUTOMATIC SETUP (சிஸ்டம் பூட் ஆகும்போதே நடக்கும் வேலைகள்) ---
    
    // 1. proc, sysfs மற்றும் devtmpfs (Hardware Devices) ஆட்டோமேட்டிக்காக mount செய்ய
    if (mount("proc", "/proc", "proc", 0, NULL) != 0) {
        printf("Warning: Failed to mount /proc\n");
    }
    mount("sysfs", "/sys", "sysfs", 0, NULL);
    mount("devtmpfs", "/dev", "devtmpfs", 0, NULL); // ---> PTY வேலை செய்ய இது மிக முக்கியம் <---

    // 2. BDH Engine-க்கான PTY (Virtual Terminal) Mount செய்தல்
    mkdir("/dev/pts", 0755);
    if (mount("devpts", "/dev/pts", "devpts", 0, NULL) != 0) {
        printf("Warning: Failed to mount /dev/pts\n");
    }

    // 3. Engine-க்கு தேவையான Bash, Zsh மற்றும் Env Variables செட் செய்தல்
    symlink("/bin/busybox", "/bin/bash");
    symlink("/bin/busybox", "/bin/zsh");
    setenv("TERM", "linux", 1);
    setenv("PATH", "/bin:/sbin:/usr/bin:/usr/sbin", 1);

    // 4. BusyBox ஷார்ட்கட்களை ஆட்டோமேட்டிக்காக உருவாக்க
    pid_t setup_pid = fork();
    if (setup_pid == 0) {
        char *setup_args[] = {"/bin/busybox", "--install", "-s", "/bin", NULL};
        execv(setup_args[0], setup_args);
        exit(1); 
    } else if (setup_pid > 0) {
        waitpid(setup_pid, NULL, 0); 
    }
    
    // -------------------------------------------------------------

    printf("======================================\n");
    printf("  Welcome to BDH Minimal OS\n");
    printf("======================================\n");

    while (1) {
        printf("BDH-OS # ");
        fflush(stdout);

        if (fgets(command, sizeof(command), stdin) == NULL) {
            clearerr(stdin);
            continue;
        }

        command[strcspn(command, "\n")] = 0;
        if (strlen(command) == 0) continue;

        if (strcmp(command, "exit") == 0) {
            printf("Init system cannot exit! Use poweroff or reboot.\n");
            continue;
        }

        int i = 0;
        char *token = strtok(command, " ");
        while (token != NULL && i < MAX_ARGS - 1) {
            args[i++] = token;
            token = strtok(NULL, " ");
        }
        args[i] = NULL;

        // cd கமாண்டுக்கான லாஜிக்
        if (strcmp(args[0], "cd") == 0) {
            if (args[1] == NULL) {
                printf("cd: missing argument\n");
            } else {
                if (chdir(args[1]) != 0) {
                    perror("cd failed");
                }
            }
            continue;
        }

        pid_t pid = fork();
        if (pid == 0) {
            if (execvp(args[0], args) == -1) {
                printf("Command not found: %s\n", args[0]);
                exit(1);
            }
        } else if (pid > 0) {
            waitpid(pid, NULL, 0);
            while (waitpid(-1, NULL, WNOHANG) > 0);
        } else {
            printf("Fork failed!\n");
        }
    }
    return 0;
}
