#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <sys/select.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <engine_path> [arguments...]\n", argv[0]);
        return 1;
    }

    int pipe_in[2];  // Parent writes to Child's stdin
    int pipe_out[2]; // Child writes to Parent's stdout

    if (pipe(pipe_in) == -1 || pipe(pipe_out) == -1) {
        perror("pipe");
        return 1;
    }

    pid_t pid = fork();

    if (pid == -1) {
        perror("fork");
        return 1;
    }

    if (pid == 0) {
        // Child process

        // Redirect stdin
        if (dup2(pipe_in[0], STDIN_FILENO) == -1) {
            perror("dup2 stdin");
            exit(1);
        }

        // Redirect stdout
        if (dup2(pipe_out[1], STDOUT_FILENO) == -1) {
            perror("dup2 stdout");
            exit(1);
        }

        // Close unused pipe ends
        close(pipe_in[0]);
        close(pipe_in[1]);
        close(pipe_out[0]);
        close(pipe_out[1]);

        // Execute the engine
        execvp(argv[1], &argv[1]);

        // If execvp returns, it failed
        perror("execvp");
        exit(1);
    } else {
        // Parent process

        // Close unused pipe ends
        close(pipe_in[0]);
        close(pipe_out[1]);

        printf("Engine started with PID %d\n", pid);

        // Example: Send "uci" to engine if it's a UCI engine
        const char *cmd = "uci\n";
        write(pipe_in[1], cmd, 4);
        printf("Sent: uci\n");

        // Read output
        char buffer[1024];
        ssize_t nbytes;

        // Read a bit of output (blocking)
        // In a real application you would use select/poll or a separate thread
        printf("Reading output (will timeout after 2 seconds if no output)...\n");

        // Simple timeout mechanism for demonstration
        fd_set set;
        struct timeval timeout;
        FD_ZERO(&set);
        FD_SET(pipe_out[0], &set);
        timeout.tv_sec = 2;
        timeout.tv_usec = 0;

        int rv = select(pipe_out[0] + 1, &set, NULL, NULL, &timeout);
        if (rv == -1) {
            perror("select");
        } else if (rv == 0) {
            printf("Timeout: No output received.\n");
        } else {
             nbytes = read(pipe_out[0], buffer, sizeof(buffer) - 1);
             if (nbytes > 0) {
                 buffer[nbytes] = '\0';
                 printf("Received:\n%s\n", buffer);
             }
        }

        // Clean up
        close(pipe_in[1]);
        close(pipe_out[0]);

        // Wait for child to finish (or kill it)
        kill(pid, SIGTERM);
        waitpid(pid, NULL, 0);
        printf("Engine terminated.\n");
    }

    return 0;
}
