#include <stdlib.h>
#include <string.h>
#include "cnufs.h"

typedef struct {
    int count;
    char *buf;
} IterVar;

static void settings_option_foreach_func(void *data, const char *name, const char *option)
{
    (void) name;
    IterVar *iter = data;
    strcat(iter->buf, option);
    strcat(iter->buf, "\n");
}

static void settings_foreach_func(void *data, const char *name, int type)
{
    IterVar *iter = data;
    strcat(iter->buf, name);
    strcat(iter->buf, "\n");
}

int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions)
{
    if (!settings) goto fn_fail;
    if (poptions == NULL || *poptions != NULL) goto fn_fail;
    int count = fluid_settings_option_count(settings, cname);
    size_t buffer_size = 256;
    IterVar iter = {
        .count = count,
        .buf = calloc(buffer_size, sizeof(char))
    };
    fluid_settings_foreach_option(settings, cname, &iter, settings_option_foreach_func);
    *poptions = iter.buf;
    return FLUID_OK;
fn_fail:
    return FLUID_FAILED;
}

int fs_settings_get_names(fluid_settings_t *settings, char **pnames)
{
    if (!settings) goto fn_fail;
    if (pnames == NULL || *pnames != NULL) goto fn_fail;
    IterVar iter = {
        .buf=calloc(1024*4, sizeof(char))
    };
    fluid_settings_foreach(settings, &iter, settings_foreach_func);
    *pnames = iter.buf;
    return FLUID_OK;
fn_fail:
    return FLUID_FAILED;
}
