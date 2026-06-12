// Open chrome://history in Thorium and sample Thorium process CPU usage.
//
// Build:
//   cc -O2 -Wall -Wextra -o /tmp/debug_thorium_history infra/debug/debug_thorium_history.c
//
// Usage:
//   /tmp/debug_thorium_history
//   /tmp/debug_thorium_history --profile "Profile 6"
//   /tmp/debug_thorium_history --monitor-only

#define _GNU_SOURCE

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define MAX_PROCS 4096
#define CMDLINE_MAX 8192

typedef struct {
  pid_t pid;
  unsigned long long ticks;
  double cpu;
  char cmdline[CMDLINE_MAX];
} Proc;

static int read_file(const char *path, char *buf, size_t size) {
  FILE *f = fopen(path, "rb");
  if (!f) return -1;
  size_t n = fread(buf, 1, size - 1, f);
  fclose(f);
  buf[n] = 0;
  return (int)n;
}

static unsigned long long total_cpu_ticks(void) {
  char buf[1024];
  if (read_file("/proc/stat", buf, sizeof(buf)) < 0) return 0;
  char *p = buf;
  if (strncmp(p, "cpu ", 4) != 0) return 0;
  p += 4;

  unsigned long long total = 0;
  while (*p) {
    while (isspace((unsigned char)*p)) p++;
    if (!isdigit((unsigned char)*p)) break;
    total += strtoull(p, &p, 10);
  }
  return total;
}

static int read_proc_ticks(pid_t pid, unsigned long long *ticks) {
  char path[64];
  char buf[4096];
  snprintf(path, sizeof(path), "/proc/%d/stat", pid);
  if (read_file(path, buf, sizeof(buf)) < 0) return -1;

  char *end = strrchr(buf, ')');
  if (!end) return -1;
  char *p = end + 2;

  // Fields after comm start at state (field 3). utime/stime are fields 14/15.
  for (int field = 3; field < 14; field++) {
    while (*p && !isspace((unsigned char)*p)) p++;
    while (isspace((unsigned char)*p)) p++;
  }

  unsigned long long utime = strtoull(p, &p, 10);
  while (isspace((unsigned char)*p)) p++;
  unsigned long long stime = strtoull(p, NULL, 10);
  *ticks = utime + stime;
  return 0;
}

static int read_cmdline(pid_t pid, char *out, size_t size) {
  char path[64];
  snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);
  int n = read_file(path, out, size);
  if (n <= 0) return -1;
  for (int i = 0; i < n; i++) {
    if (out[i] == '\0') out[i] = ' ';
  }
  out[n] = '\0';
  return 0;
}

static int is_thorium_cmd(const char *cmdline) {
  return strstr(cmdline, "thorium") != NULL &&
         (strstr(cmdline, "/opt/thorium-browser/") != NULL ||
          strstr(cmdline, "thorium-browser") != NULL);
}

static const char *proc_type(const char *cmdline) {
  const char *type = strstr(cmdline, "--type=");
  if (!type) return "browser";
  type += strlen("--type=");
  static char buf[64];
  size_t i = 0;
  while (type[i] && !isspace((unsigned char)type[i]) && i + 1 < sizeof(buf)) {
    buf[i] = type[i];
    i++;
  }
  buf[i] = '\0';
  return buf;
}

static int collect(Proc *procs, int max) {
  DIR *dir = opendir("/proc");
  if (!dir) return 0;

  int count = 0;
  struct dirent *ent;
  while ((ent = readdir(dir)) != NULL && count < max) {
    if (!isdigit((unsigned char)ent->d_name[0])) continue;
    pid_t pid = (pid_t)atoi(ent->d_name);

    char cmdline[CMDLINE_MAX];
    if (read_cmdline(pid, cmdline, sizeof(cmdline)) < 0) continue;
    if (!is_thorium_cmd(cmdline)) continue;

    unsigned long long ticks = 0;
    if (read_proc_ticks(pid, &ticks) < 0) continue;

    procs[count].pid = pid;
    procs[count].ticks = ticks;
    procs[count].cpu = 0.0;
    snprintf(procs[count].cmdline, sizeof(procs[count].cmdline), "%s", cmdline);
    count++;
  }

  closedir(dir);
  return count;
}

static Proc *find_proc(Proc *procs, int count, pid_t pid) {
  for (int i = 0; i < count; i++) {
    if (procs[i].pid == pid) return &procs[i];
  }
  return NULL;
}

static int cmp_cpu_desc(const void *a, const void *b) {
  const Proc *pa = (const Proc *)a;
  const Proc *pb = (const Proc *)b;
  return (pb->cpu > pa->cpu) - (pb->cpu < pa->cpu);
}

static void open_history(const char *browser, const char *profile) {
  pid_t child = fork();
  if (child < 0) {
    perror("fork");
    return;
  }

  if (child == 0) {
    if (profile && profile[0]) {
      char arg[256];
      snprintf(arg, sizeof(arg), "--profile-directory=%s", profile);
      execlp(browser, browser, arg, "chrome://history", (char *)NULL);
    } else {
      execlp(browser, browser, "chrome://history", (char *)NULL);
    }
    perror("execlp");
    _exit(127);
  }

  int status = 0;
  waitpid(child, &status, 0);
}

static void usage(const char *argv0) {
  fprintf(stderr,
          "Usage: %s [--browser PATH] [--profile NAME] [--samples N] [--interval SEC] [--monitor-only]\n",
          argv0);
}

int main(int argc, char **argv) {
  const char *browser = "thorium-browser";
  const char *profile = NULL;
  int samples = 120;
  int interval = 1;
  int monitor_only = 0;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--browser") == 0 && i + 1 < argc) {
      browser = argv[++i];
    } else if (strcmp(argv[i], "--profile") == 0 && i + 1 < argc) {
      profile = argv[++i];
    } else if (strcmp(argv[i], "--samples") == 0 && i + 1 < argc) {
      samples = atoi(argv[++i]);
    } else if (strcmp(argv[i], "--interval") == 0 && i + 1 < argc) {
      interval = atoi(argv[++i]);
      if (interval < 1) interval = 1;
    } else if (strcmp(argv[i], "--monitor-only") == 0) {
      monitor_only = 1;
    } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
      usage(argv[0]);
      return 0;
    } else {
      usage(argv[0]);
      return 2;
    }
  }

  if (!monitor_only) {
    fprintf(stderr, "Opening chrome://history with %s", browser);
    if (profile) fprintf(stderr, " profile=%s", profile);
    fprintf(stderr, "\n");
    open_history(browser, profile);
  }

  Proc *prev = calloc(MAX_PROCS, sizeof(*prev));
  Proc *cur = calloc(MAX_PROCS, sizeof(*cur));
  if (!prev || !cur) {
    fprintf(stderr, "failed to allocate process buffers\n");
    return 1;
  }
  int prev_count = collect(prev, MAX_PROCS);
  unsigned long long prev_total = total_cpu_ticks();
  long cpus = sysconf(_SC_NPROCESSORS_ONLN);
  if (cpus < 1) cpus = 1;

  for (int sample = 1; sample <= samples; sample++) {
    sleep((unsigned int)interval);

    int cur_count = collect(cur, MAX_PROCS);
    unsigned long long cur_total = total_cpu_ticks();
    unsigned long long total_delta = cur_total - prev_total;
    if (total_delta == 0) total_delta = 1;

    for (int i = 0; i < cur_count; i++) {
      Proc *old = find_proc(prev, prev_count, cur[i].pid);
      if (!old) continue;
      unsigned long long delta = cur[i].ticks - old->ticks;
      cur[i].cpu = 100.0 * (double)delta * (double)cpus / (double)total_delta;
    }

    qsort(cur, (size_t)cur_count, sizeof(cur[0]), cmp_cpu_desc);

    time_t now = time(NULL);
    char ts[64];
    strftime(ts, sizeof(ts), "%H:%M:%S", localtime(&now));
    printf("\n[%s] sample %d/%d\n", ts, sample, samples);

    int shown = 0;
    for (int i = 0; i < cur_count && shown < 10; i++) {
      if (cur[i].cpu < 1.0) continue;
      printf("%7d %6.1f%% %-18s %s\n",
             cur[i].pid, cur[i].cpu, proc_type(cur[i].cmdline), cur[i].cmdline);
      shown++;
    }
    if (!shown) printf("No Thorium process above 1%% CPU.\n");
    fflush(stdout);

    memcpy(prev, cur, MAX_PROCS * sizeof(*cur));
    prev_count = cur_count;
    prev_total = cur_total;
  }

  free(prev);
  free(cur);
  return 0;
}
