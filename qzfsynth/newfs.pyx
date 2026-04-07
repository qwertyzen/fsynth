from libc.stdlib cimport free

cdef extern from "fluidsynth.h":
    cdef void fluid_version(int *major, int *minor, int *micro)
    cdef int FLUID_OK
    cdef int FLUID_NO_TYPE
    cdef int FLUID_NUM_TYPE
    cdef int FLUID_INT_TYPE
    cdef int FLUID_STR_TYPE
    cdef int FLUID_SET_TYPE
    struct fluid_settings_s
    ctypedef fluid_settings_s fluid_settings_t
    cdef fluid_settings_t *new_fluid_settings()
    cdef void delete_fluid_settings(fluid_settings_t *settings)

    cdef int fluid_settings_get_type(fluid_settings_t *settings, const char *name)
    cdef int fluid_settings_get_hints(fluid_settings_t *settings, const char *name, int *val)
    cdef int fluid_settings_is_realtime(fluid_settings_t *settings, const char *name)
    cdef int fluid_settings_setstr(fluid_settings_t *settings, const char *name, const char *str)
    cdef int fluid_settings_copystr(fluid_settings_t *settings, const char *name, char *str, int len)
    cdef int fluid_settings_dupstr(fluid_settings_t *settings, const char *name, char **str)
    cdef int fluid_settings_getstr_default(fluid_settings_t *settings, const char *name, char **default)
    cdef int fluid_settings_str_equal(fluid_settings_t *settings, const char *name, const char *value)
    cdef int fluid_settings_setnum(fluid_settings_t *settings, const char *name, double val)
    cdef int fluid_settings_getnum(fluid_settings_t *settings, const char *name, double *val)
    cdef int fluid_settings_getnum_default(fluid_settings_t *settings, const char *name, double *val)
    cdef int fluid_settings_getnum_range(fluid_settings_t *settings, const char *namem,
                                double *min, double *max)
    cdef int fluid_settings_setint(fluid_settings_t *settings, const char *name, int val)
    cdef int fluid_settings_getint(fluid_settings_t *settings, const char *name, int *val)
    cdef int fluid_settings_getint_default(fluid_settings_t *settings, const char *name, int *val)
    cdef int fluid_settings_getint_range(fluid_settings_t *settings, const char *name, int *min, int *max)

    ctypedef void (*fluid_settings_foreach_option_t)(void *data, const char *name, const char *option);


    cdef void fluid_settings_foreach_option(fluid_settings_t *settings,
                                   const char *name, void *data,
                                   fluid_settings_foreach_option_t func);

    cdef int fluid_settings_option_count(fluid_settings_t *settings, const char *name);
    cdef char *fluid_settings_option_concat(fluid_settings_t *settings,
        const char *name,
        const char *separator);

    ctypedef void (*fluid_settings_foreach_t)(void *data, const char *name, int type);

    cdef void fluid_settings_foreach(fluid_settings_t *settings, void *data,
                            fluid_settings_foreach_t func);

cdef extern from "cnufs.h":
    cdef int fs_settings_get_options(fluid_settings_t *settings, const char *cname, char **poptions)
    cdef int fs_settings_get_names(fluid_settings_t *settings, char **pames)

cdef class Settings:
    cdef fluid_settings_t *ptr
    cdef bytes _setting_names

    def __cinit__(self):
        self.ptr = new_fluid_settings()
        if not self.ptr:
            raise RuntimeError
        self._get_names()

    def __dealloc__(self):
        if self.ptr:
            delete_fluid_settings(self.ptr)
            self.ptr = NULL

    cdef _get_names(self):
        cdef int err
        cdef char *c_names = NULL
        err = fs_settings_get_names(self.ptr, &c_names)
        if err != FLUID_OK:
            raise Exception
        self._setting_names = c_names
        free(c_names)

    @property
    def names(self) -> str:
        return self._setting_names.decode('utf-8')

    def get(self, name: str) -> str | int | float:
        cdef bytes bname = name.encode('utf-8')

        cdef int err
        cdef char[256] cvalue
        cdef str strval
        cdef int intval
        cdef double floatval
        cdef int setting_type = fluid_settings_get_type(self.ptr, bname)
        if setting_type == FLUID_INT_TYPE:
            err = fluid_settings_getint(self.ptr, bname, &intval)
            if err != FLUID_OK:
                raise ValueError
            return intval
        elif setting_type == FLUID_NUM_TYPE:
            err = fluid_settings_getnum(self.ptr, bname, &floatval)
            if err != FLUID_OK:
                raise ValueError
            return floatval
        elif setting_type == FLUID_STR_TYPE:
            err = fluid_settings_copystr(self.ptr, bname, cvalue, 256)
            strval = cvalue.decode('utf-8')
            return strval
        raise TypeError

    def set(self, name: str, value: str | int | float):
        cdef bytes bname = name.encode('utf-8')
        cdef const char *cname = bname

        cdef bytes csetval
        if type(value) is int:
            err = fluid_settings_setint(self.ptr, cname, value)
        elif type(value) is float:
            err = fluid_settings_setnum(self.ptr, cname, value)
        elif type(value) is str:
            csetval = value.encode('utf-8')
            err = fluid_settings_setstr(self.ptr, cname, csetval)
        else:
            raise TypeError
        if err != FLUID_OK:
            raise ValueError

    def get_default(self, name: str) -> str | int | float:
        cdef bytes bname = name.encode('utf-8')

        cdef int err
        cdef char *cvalue
        cdef str strval
        cdef int intval
        cdef double floatval
        cdef int setting_type = fluid_settings_get_type(self.ptr, bname)
        if setting_type == FLUID_INT_TYPE:
            err = fluid_settings_getint_default(self.ptr, bname, &intval)
            if err != FLUID_OK:
                raise ValueError
            return intval
        elif setting_type == FLUID_NUM_TYPE:
            err = fluid_settings_getnum_default(self.ptr, bname, &floatval)
            if err != FLUID_OK:
                raise ValueError
            return floatval
        elif setting_type == FLUID_STR_TYPE:
            err = fluid_settings_getstr_default(self.ptr, bname, &cvalue)
            strval = cvalue.decode('utf-8')
            return strval
        raise TypeError

    def get_range(self, name: str) -> tuple[int, int] | tuple[float, float]:
        cdef bytes bname = name.encode('utf-8')

        cdef int err
        cdef int imax, imin
        cdef double fmax, fmin
        cdef int setting_type = fluid_settings_get_type(self.ptr, bname)
        if setting_type == FLUID_INT_TYPE:
            err = fluid_settings_getint_range(self.ptr, bname, &imin, &imax)
            if err != FLUID_OK:
                raise ValueError
            return imin, imax
        elif setting_type == FLUID_NUM_TYPE:
            err = fluid_settings_getnum_range(self.ptr, bname, &fmin, &fmax)
            if err != FLUID_OK:
                raise ValueError
            return fmin, fmax
        else:
            raise TypeError

    def get_options(self, name: str) -> list[str]:
        cdef int err
        cdef bytes bname = name.encode('utf-8')
        cdef char *copts = NULL

        err = fs_settings_get_options(self.ptr, bname, &copts)
        if err != FLUID_OK:
            raise Exception
        cdef bytes bopts = copts
        cdef str opts = bopts.decode('utf-8').strip()
        free(copts)
        return opts.split('\n')

def enumerate_audio_devices(audio_driver: str) -> str:
    cdef int err
    cdef fluid_settings_t *settings
    settings = new_fluid_settings()
    if settings == NULL:
        raise RuntimeError
    cdef bytes adriver = f'audio.{audio_driver}.device'.encode('utf-8')
    cdef char *c_opts = NULL
