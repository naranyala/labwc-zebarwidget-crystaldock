#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <pwd.h>

#define MAX_IFACES 32
#define MAX_LINE 1024

struct iface_stat {
    char name[64];
    unsigned long long rx_bytes;
    unsigned long long tx_bytes;
    unsigned long long timestamp;
};

struct iface_rate {
    char name[64];
    unsigned long long rx_rate;
    unsigned long long tx_rate;
    unsigned long long timestamp;
};


struct daily_stat {
    char date_str[16];
    char name[64];
    unsigned long long total_rx;
    unsigned long long total_tx;
    unsigned long long last_rx_abs;
    unsigned long long last_tx_abs;
};

void get_state_dir(char *path, size_t size) {
    const char *ocws_dir = getenv("OCWS_DIR");
    if (ocws_dir) {
        snprintf(path, size, "%s/state", ocws_dir);
    } else {
        const char *home = getenv("HOME");
        if (!home) {
            struct passwd *pw = getpwuid(getuid());
            home = pw->pw_dir;
        }
        snprintf(path, size, "%s/.config/ocws/state", home);
    }
}

void get_ocws_dir(char *path, size_t size) {
    const char *ocws_dir = getenv("OCWS_DIR");
    if (ocws_dir) {
        snprintf(path, size, "%s", ocws_dir);
    } else {
        const char *home = getenv("HOME");
        if (!home) {
            struct passwd *pw = getpwuid(getuid());
            home = pw->pw_dir;
        }
        snprintf(path, size, "%s/.config/ocws", home);
    }
}

void mkdir_p(const char *dir) {
    char tmp[256];
    char *p = NULL;
    size_t len;

    snprintf(tmp, sizeof(tmp), "%s", dir);
    len = strlen(tmp);
    if (tmp[len - 1] == '/')
        tmp[len - 1] = 0;
    for (p = tmp + 1; *p; p++)
        if (*p == '/') {
            *p = 0;
            mkdir(tmp, 0755);
            *p = '/';
        }
    mkdir(tmp, 0755);
}

int read_proc_net_dev(struct iface_stat *ifaces, int max_ifaces) {
    FILE *f = fopen("/proc/net/dev", "r");
    if (!f) return 0;

    char line[MAX_LINE];
    int count = 0;
    unsigned long long now = (unsigned long long)time(NULL);

    while (fgets(line, sizeof(line), f) && count < max_ifaces) {
        if (strstr(line, "Inter-") || strstr(line, " face")) continue;
        if (strstr(line, "lo:")) continue; // Skip loopback

        char *colon = strchr(line, ':');
        if (colon) {
            *colon = '\0';
            char *name = line;
            while (*name == ' ') name++; // trim leading spaces
            
            unsigned long long rx_bytes, tx_bytes;
            if (sscanf(colon + 1, "%llu %*u %*u %*u %*u %*u %*u %*u %llu", &rx_bytes, &tx_bytes) == 2) {
                strncpy(ifaces[count].name, name, sizeof(ifaces[count].name) - 1);
                ifaces[count].rx_bytes = rx_bytes;
                ifaces[count].tx_bytes = tx_bytes;
                ifaces[count].timestamp = now;
                count++;
            }
        }
    }
    fclose(f);
    return count;
}

int read_stats(const char *filepath, struct iface_stat *ifaces, int max_ifaces) {
    FILE *f = fopen(filepath, "r");
    if (!f) return 0;
    
    char line[MAX_LINE];
    int count = 0;
    while (fgets(line, sizeof(line), f) && count < max_ifaces) {
        if (sscanf(line, "%63s %llu %llu %llu", ifaces[count].name, &ifaces[count].rx_bytes, &ifaces[count].tx_bytes, &ifaces[count].timestamp) == 4) {
            count++;
        }
    }
    fclose(f);
    return count;
}

void cmd_update() {
    char state_dir[256];
    char ocws_dir[256];
    get_state_dir(state_dir, sizeof(state_dir));
    get_ocws_dir(ocws_dir, sizeof(ocws_dir));
    mkdir_p(state_dir);
    mkdir_p(ocws_dir);

    char stats_file[512], history_file[512], widget_file[512];
    snprintf(stats_file, sizeof(stats_file), "%s/network-stats", state_dir);
    snprintf(history_file, sizeof(history_file), "%s/network-history", state_dir);
    snprintf(widget_file, sizeof(widget_file), "%s/widget-bandwidth-data", ocws_dir);

    struct iface_stat current[MAX_IFACES];
    int cur_count = read_proc_net_dev(current, MAX_IFACES);

    struct iface_stat previous[MAX_IFACES];
    int prev_count = read_stats(stats_file, previous, MAX_IFACES);

    FILE *f_stats = fopen(stats_file, "w");
    if (!f_stats) return;

    FILE *f_hist = fopen(history_file, "a");
    FILE *f_widget = fopen(widget_file, "w");

    time_t rawtime = time(NULL);
    struct tm *info = localtime(&rawtime);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", info);


    // --- Daily Tracking Logic ---
    char daily_file[512];
    snprintf(daily_file, sizeof(daily_file), "%s/network-daily.dat", state_dir);
    struct daily_stat daily_stats[MAX_IFACES];
    int daily_count = 0;
    
    FILE *f_daily_in = fopen(daily_file, "r");
    if (f_daily_in) {
        char line[MAX_LINE];
        while (fgets(line, sizeof(line), f_daily_in) && daily_count < MAX_IFACES) {
            if (sscanf(line, "%15s %63s %llu %llu %llu %llu", 
                       daily_stats[daily_count].date_str, daily_stats[daily_count].name, 
                       &daily_stats[daily_count].total_rx, &daily_stats[daily_count].total_tx,
                       &daily_stats[daily_count].last_rx_abs, &daily_stats[daily_count].last_tx_abs) == 6) {
                daily_count++;
            }
        }
        fclose(f_daily_in);
    }

    char cur_date[16];
    time_t rawtime_tmp = time(NULL); struct tm *info_tmp = localtime(&rawtime_tmp); strftime(cur_date, sizeof(cur_date), "%Y-%m-%d", info_tmp);

    FILE *f_daily_out = fopen(daily_file, "w");

    for (int i = 0; i < cur_count; i++) {
        fprintf(f_stats, "%s %llu %llu %llu\n", current[i].name, current[i].rx_bytes, current[i].tx_bytes, current[i].timestamp);
        
        unsigned long long rx_rate = 0, tx_rate = 0;
        for (int j = 0; j < prev_count; j++) {
            if (strcmp(current[i].name, previous[j].name) == 0) {
                unsigned long long time_diff = current[i].timestamp - previous[j].timestamp;
                if (time_diff > 0) {
                    unsigned long long rx_diff = (current[i].rx_bytes >= previous[j].rx_bytes) ? (current[i].rx_bytes - previous[j].rx_bytes) : 0;
                    unsigned long long tx_diff = (current[i].tx_bytes >= previous[j].tx_bytes) ? (current[i].tx_bytes - previous[j].tx_bytes) : 0;
                    rx_rate = rx_diff / time_diff;
                    tx_rate = tx_diff / time_diff;
                }
                break;
            }
        }
        
        if (f_hist) {
            fprintf(f_hist, "%s %llu %llu %llu\n", current[i].name, rx_rate, tx_rate, current[i].timestamp);
        }
        
        
        // Update daily stats
        int found_daily = 0;
        for (int k = 0; k < daily_count; k++) {
            if (strcmp(daily_stats[k].name, current[i].name) == 0) {
                found_daily = 1;
                if (strcmp(daily_stats[k].date_str, cur_date) != 0) {
                    // New day! Reset
                    strncpy(daily_stats[k].date_str, cur_date, sizeof(daily_stats[k].date_str) - 1);
                    daily_stats[k].total_rx = 0;
                    daily_stats[k].total_tx = 0;
                }
                
                if (current[i].rx_bytes >= daily_stats[k].last_rx_abs) {
                    daily_stats[k].total_rx += (current[i].rx_bytes - daily_stats[k].last_rx_abs);
                } else {
                    // Reboot or counter wrap
                    daily_stats[k].total_rx += current[i].rx_bytes;
                }
                
                if (current[i].tx_bytes >= daily_stats[k].last_tx_abs) {
                    daily_stats[k].total_tx += (current[i].tx_bytes - daily_stats[k].last_tx_abs);
                } else {
                    daily_stats[k].total_tx += current[i].tx_bytes;
                }
                
                daily_stats[k].last_rx_abs = current[i].rx_bytes;
                daily_stats[k].last_tx_abs = current[i].tx_bytes;
                
                if (f_daily_out) {
                    fprintf(f_daily_out, "%s %s %llu %llu %llu %llu\n", 
                            daily_stats[k].date_str, daily_stats[k].name, 
                            daily_stats[k].total_rx, daily_stats[k].total_tx, 
                            daily_stats[k].last_rx_abs, daily_stats[k].last_tx_abs);
                }
                break;
            }
        }
        
        if (!found_daily && daily_count < MAX_IFACES && f_daily_out) {
            fprintf(f_daily_out, "%s %s 0 0 %llu %llu\n", 
                    cur_date, current[i].name, current[i].rx_bytes, current[i].tx_bytes);
            
            // Add to in-memory so we track it next loop
            strncpy(daily_stats[daily_count].date_str, cur_date, sizeof(daily_stats[daily_count].date_str) - 1);
            strncpy(daily_stats[daily_count].name, current[i].name, sizeof(daily_stats[daily_count].name) - 1);
            daily_stats[daily_count].total_rx = 0;
            daily_stats[daily_count].total_tx = 0;
            daily_stats[daily_count].last_rx_abs = current[i].rx_bytes;
            daily_stats[daily_count].last_tx_abs = current[i].tx_bytes;
            daily_count++;
        }

        if (f_widget) {
            // Write JSON matching the exact structure from bash
            fprintf(f_widget, "{\"iface\": \"%s\", \"rx_rate\": %llu, \"tx_rate\": %llu, \"timestamp\": \"%s\"}\n",
                    current[i].name, rx_rate, tx_rate, time_str);
        }
    }

    fclose(f_stats);
    if (f_hist) fclose(f_hist);
    if (f_widget) fclose(f_widget);
    if (f_daily_out) fclose(f_daily_out);
}

void cmd_get(const char *iface) {
    char state_dir[256];
    get_state_dir(state_dir, sizeof(state_dir));
    char stats_file[512];
    snprintf(stats_file, sizeof(stats_file), "%s/network-stats", state_dir);

    struct iface_stat previous[MAX_IFACES];
    int prev_count = read_stats(stats_file, previous, MAX_IFACES);

    struct iface_stat current[MAX_IFACES];
    int cur_count = read_proc_net_dev(current, MAX_IFACES);


    // --- Daily Tracking Logic ---
    char daily_file[512];
    snprintf(daily_file, sizeof(daily_file), "%s/network-daily.dat", state_dir);
    struct daily_stat daily_stats[MAX_IFACES];
    int daily_count = 0;
    
    FILE *f_daily_in = fopen(daily_file, "r");
    if (f_daily_in) {
        char line[MAX_LINE];
        while (fgets(line, sizeof(line), f_daily_in) && daily_count < MAX_IFACES) {
            if (sscanf(line, "%15s %63s %llu %llu %llu %llu", 
                       daily_stats[daily_count].date_str, daily_stats[daily_count].name, 
                       &daily_stats[daily_count].total_rx, &daily_stats[daily_count].total_tx,
                       &daily_stats[daily_count].last_rx_abs, &daily_stats[daily_count].last_tx_abs) == 6) {
                daily_count++;
            }
        }
        fclose(f_daily_in);
    }

    char cur_date[16];
    time_t rawtime_tmp = time(NULL); struct tm *info_tmp = localtime(&rawtime_tmp); strftime(cur_date, sizeof(cur_date), "%Y-%m-%d", info_tmp);

    FILE *f_daily_out = fopen(daily_file, "w");

    for (int i = 0; i < cur_count; i++) {
        if (strcmp(current[i].name, iface) == 0) {
            for (int j = 0; j < prev_count; j++) {
                if (strcmp(previous[j].name, iface) == 0) {
                    unsigned long long time_diff = current[i].timestamp - previous[j].timestamp;
                    if (time_diff > 0) {
                        unsigned long long rx_diff = (current[i].rx_bytes >= previous[j].rx_bytes) ? (current[i].rx_bytes - previous[j].rx_bytes) : 0;
                        unsigned long long tx_diff = (current[i].tx_bytes >= previous[j].tx_bytes) ? (current[i].tx_bytes - previous[j].tx_bytes) : 0;
                        printf("%llu %llu\n", rx_diff / time_diff, tx_diff / time_diff);
                        return;
                    }
                }
            }
        }
    }
    printf("0 0\n");
}

void cmd_avg(const char *iface, int period) {
    char state_dir[256];
    get_state_dir(state_dir, sizeof(state_dir));
    char history_file[512];
    snprintf(history_file, sizeof(history_file), "%s/network-history", state_dir);

    FILE *f = fopen(history_file, "r");
    if (!f) {
        printf("0 0\n");
        return;
    }

    char line[MAX_LINE];
    unsigned long long now = (unsigned long long)time(NULL);
    unsigned long long total_rx = 0, total_tx = 0;
    int count = 0;

    while (fgets(line, sizeof(line), f)) {
        char name[64];
        unsigned long long rx_rate, tx_rate, timestamp;
        if (sscanf(line, "%63s %llu %llu %llu", name, &rx_rate, &tx_rate, &timestamp) == 4) {
            if (strcmp(name, iface) == 0) {
                if (now - timestamp <= (unsigned long long)period) {
                    total_rx += rx_rate;
                    total_tx += tx_rate;
                    count++;
                }
            }
        }
    }
    fclose(f);

    if (count > 0) {
        printf("%llu %llu\n", total_rx / count, total_tx / count);
    } else {
        printf("0 0\n");
    }
}


void cmd_daily(const char *iface) {
    char state_dir[256];
    get_state_dir(state_dir, sizeof(state_dir));
    char daily_file[512];
    snprintf(daily_file, sizeof(daily_file), "%s/network-daily.dat", state_dir);

    FILE *f = fopen(daily_file, "r");
    if (!f) {
        printf("0 0\n");
        return;
    }

    char line[MAX_LINE];
    while (fgets(line, sizeof(line), f)) {
        struct daily_stat ds;
        if (sscanf(line, "%15s %63s %llu %llu %llu %llu", 
                   ds.date_str, ds.name, &ds.total_rx, &ds.total_tx,
                   &ds.last_rx_abs, &ds.last_tx_abs) == 6) {
            if (strcmp(ds.name, iface) == 0) {
                printf("%llu %llu\n", ds.total_rx, ds.total_tx);
                fclose(f);
                return;
            }
        }
    }
    fclose(f);
    printf("0 0\n");
}

void cmd_cleanup() {
    char state_dir[256];
    get_state_dir(state_dir, sizeof(state_dir));
    char stats_file[512], history_file[512];
    snprintf(stats_file, sizeof(stats_file), "%s/network-stats", state_dir);
    snprintf(history_file, sizeof(history_file), "%s/network-history", state_dir);

    remove(stats_file);
    remove(history_file);
    printf("Network stats cleaned\n");
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    if (argc < 2) {
        printf("Usage: %s <command> [args]\n", argv[0]);
        printf("Commands:\n");
        printf("  update      Update network statistics\n");
        printf("  get IFACE   Get current bandwidth for interface\n");
        printf("  avg IFACE [SECONDS]   Get average bandwidth over time\n");
        printf("  cleanup     Clear stored network stats\n");
        return 0;
    }

    if (strcmp(argv[1], "update") == 0) {
        cmd_update();
    } else if (strcmp(argv[1], "get") == 0 && argc >= 3) {
        cmd_get(argv[2]);
    } else if (strcmp(argv[1], "avg") == 0 && argc >= 3) {
        int period = 3600;
        if (argc >= 4) {
            period = atoi(argv[3]);
        }
        cmd_avg(argv[2], period);
        } else if (strcmp(argv[1], "daily") == 0 && argc >= 3) {
        cmd_daily(argv[2]);
    } else if (strcmp(argv[1], "cleanup") == 0) {
        cmd_cleanup();
    } else {
        printf("Invalid command or missing arguments.\n");
    }

    return 0;
}
