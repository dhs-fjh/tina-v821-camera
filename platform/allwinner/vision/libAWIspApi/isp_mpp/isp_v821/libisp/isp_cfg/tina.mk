# Makefile for libisp/isp_cfg
CUR_PATH := .
LIBISP_DIR = ./../

#set source files here.
SRCCS := \
	$(wildcard ./*.c)

#include directories
INCLUDE_DIRS := \
	$(CUR_PATH) \
	$(CUR_PATH)/SENSOR_H \
	$(CUR_PATH)/../iniparser/src/ \
	$(CUR_PATH)/../include/ \
	$(CUR_PATH)/../isp_dev/ \
	$(CUR_PATH)/../isp_math/zlib/include

LOCAL_SHARED_LIBS :=

LOCAL_STATIC_LIBS :=

#set dst file name: shared library, static library, execute bin.
LOCAL_TARGET_DYNAMIC := 
LOCAL_TARGET_STATIC := libisp_ini
LOCAL_TARGET_BIN :=

#generate include directory flags for gcc.
inc_paths := $(foreach inc,$(filter-out -I%,$(INCLUDE_DIRS)),$(addprefix -I, $(inc))) \
				$(filter -I%, $(INCLUDE_DIRS))
#Extra flags to give to the C compiler
LOCAL_CFLAGS := $(CFLAGS) $(inc_paths) -fPIC -Wall
#Extra flags to give to the C++ compiler
LOCAL_CXXFLAGS := $(CXXFLAGS) $(inc_paths) -fPIC -Wall
ifeq ($(findstring imx386,$(SENSOR_NAME)), imx386)
	LOCAL_CFLAGS += -DSENSOR_IMX386=1
	LOCAL_CXXFLAGS += -DSENSOR_IMX386=1
endif
ifeq ($(findstring gc4663,$(SENSOR_NAME)), gc4663)
	LOCAL_CFLAGS += -DSENSOR_GC4663=1
	LOCAL_CXXFLAGS += -DSENSOR_GC4663=1
endif
ifeq ($(findstring gc1084,$(SENSOR_NAME)), gc1084)
	LOCAL_CFLAGS += -DSENSOR_GC1084=1
	LOCAL_CXXFLAGS += -DSENSOR_GC1084=1
ifeq ($(findstring gc1084_8bit,$(SENSOR_NAME)), gc1084_8bit)
	LOCAL_CFLAGS += -DSENSOR_GC1084_8BIT=1
	LOCAL_CXXFLAGS += -DSENSOR_GC1084_8BIT=1
endif
endif
ifeq ($(findstring gc2053,$(SENSOR_NAME)), gc2053)
	LOCAL_CFLAGS += -DSENSOR_GC2053=1
	LOCAL_CXXFLAGS += -DSENSOR_GC2053=1
ifeq ($(findstring gc2053_8bit,$(SENSOR_NAME)), gc2053_8bit)
	LOCAL_CFLAGS += -DSENSOR_GC2053_8BIT=1
	LOCAL_CXXFLAGS += -DSENSOR_GC2053_8BIT=1
endif
endif

ifeq ($(findstring gc0406,$(SENSOR_NAME)), gc0406)
	LOCAL_CFLAGS += -DSENSOR_GC0406=1
	LOCAL_CXXFLAGS += -DSENSOR_GC0406=1
endif
ifeq ($(findstring gc2083,$(SENSOR_NAME)), gc2083)
	LOCAL_CFLAGS += -DSENSOR_GC2083=1
	LOCAL_CXXFLAGS += -DSENSOR_GC2083=1
endif
ifeq ($(findstring gc02m1,$(SENSOR_NAME)), gc02m1)
	LOCAL_CFLAGS += -DSENSOR_GC02M1=1
	LOCAL_CXXFLAGS += -DSENSOR_GC02M1=1
endif
ifeq ($(findstring f37p,$(SENSOR_NAME)), f37p)
	LOCAL_CFLAGS += -DSENSOR_F37P=1
	LOCAL_CXXFLAGS += -DSENSOR_F37P=1
endif
ifeq ($(findstring f355p,$(SENSOR_NAME)), f355p)
	LOCAL_CFLAGS += -DSENSOR_F355P=1
	LOCAL_CXXFLAGS += -DSENSOR_F355P=1
endif
ifeq ($(findstring mis2008,$(SENSOR_NAME)), mis2008)
	LOCAL_CFLAGS += -DSENSOR_MIS2008=1
	LOCAL_CXXFLAGS += -DSENSOR_MIS2008=1
endif
ifeq ($(findstring sc1346,$(SENSOR_NAME)), sc1346)
	LOCAL_CFLAGS += -DSENSOR_SC1346=1
	LOCAL_CXXFLAGS += -DSENSOR_SC1346=1
endif
ifeq ($(findstring sp1405,$(SENSOR_NAME)), sp1405)
    LOCAL_CFLAGS += -DSENSOR_SP1405=1
    LOCAL_CXXFLAGS += -DSENSOR_SP1405=1
endif
ifeq ($(findstring sc2336,$(SENSOR_NAME)), sc2336)
	LOCAL_CFLAGS += -DSENSOR_SC2336=1
	LOCAL_CXXFLAGS += -DSENSOR_SC2336=1
endif
ifeq ($(findstring sc2355,$(SENSOR_NAME)), sc2355)
	LOCAL_CFLAGS += -DSENSOR_sc2355=1
	LOCAL_CXXFLAGS += -DSENSOR_sc2355=1
endif
ifeq ($(findstring sc3336,$(SENSOR_NAME)), sc3336)
	LOCAL_CFLAGS += -DSENSOR_SC3336=1
	LOCAL_CXXFLAGS += -DSENSOR_SC3336=1
endif
ifeq ($(findstring gc4663,$(SENSOR_NAME)), gc4663)
	LOCAL_CFLAGS += -DSENSOR_GC4663=1
	LOCAL_CXXFLAGS += -DSENSOR_GC4663=1
endif
ifeq ($(findstring imx258,$(SENSOR_NAME)), imx258)
	LOCAL_CFLAGS += -DSENSOR_IMX258=1
	LOCAL_CXXFLAGS += -DSENSOR_IMX258=1
endif
ifeq ($(findstring sc4336,$(SENSOR_NAME)), sc4336)
	LOCAL_CFLAGS += -DSENSOR_SC4336=1
	LOCAL_CXXFLAGS += -DSENSOR_SC4336=1
endif
ifeq ($(findstring sc4336p,$(SENSOR_NAME)), sc4336p)
	LOCAL_CFLAGS += -DSENSOR_SC4336P=1
	LOCAL_CXXFLAGS += -DSENSOR_SC433P=1
endif
ifeq ($(findstring sc5336,$(SENSOR_NAME)), sc5336)
	LOCAL_CFLAGS += -DSENSOR_SC5336=1
	LOCAL_CXXFLAGS += -DSENSOR_SC5336=1
endif
ifeq ($(findstring os02g10,$(SENSOR_NAME)), os02g10)
	LOCAL_CFLAGS += -DSENSOR_OS02G10=1
	LOCAL_CXXFLAGS += -DSENSOR_OS02G10=1
endif
ifeq ($(findstring bf2257cs,$(SENSOR_NAME)), bf2257cs)
	LOCAL_CFLAGS += -DSENSOR_BF2257CS=1
	LOCAL_CXXFLAGS += -DSENSOR_BF2257CS=1
endif
ifeq ($(findstring sc202cs,$(SENSOR_NAME)), sc202cs)
	LOCAL_CFLAGS += -DSENSOR_SC202CS=1
	LOCAL_CXXFLAGS += -DSENSOR_SC202CS=1
endif
ifeq ($(findstring sc2336p,$(SENSOR_NAME)), sc2336p)
	LOCAL_CFLAGS += -DSENSOR_SC2336P=1
	LOCAL_CXXFLAGS += -DSENSOR_SC2336P=1
endif
ifeq ($(findstring sc200ai,$(SENSOR_NAME)), sc200ai)
	LOCAL_CFLAGS += -DSENSOR_SC200AI=1
	LOCAL_CXXFLAGS += -DSENSOR_SC200AI=1
ifeq ($(findstring sc200ai_8bit,$(SENSOR_NAME)), sc200ai_8bit)
	LOCAL_CFLAGS += -DSENSOR_SC200AI_8BIT=1
	LOCAL_CXXFLAGS += -DSENSOR_SC200AI_8BIT=1
endif
endif
#Extra flags to give to the C preprocessor and programs that use it (the C and Fortran compilers).
LOCAL_CPPFLAGS := $(CPPFLAGS) $(LIBISP_CFG_CFLAGS)
#target device arch: x86, arm
LOCAL_TARGET_ARCH := $(ARCH)
#Extra flags to give to compilers when they are supposed to invoke the linker,‘ld’.
LOCAL_LDFLAGS := $(LDFLAGS) $(LIBISP_CFG_CFLAGS)

LOCAL_DYNAMIC_LDFLAGS := $(LOCAL_LDFLAGS) -shared \
	-Wl,-Bstatic \
	-Wl,--start-group $(foreach n, $(LOCAL_STATIC_LIBS), -l$(patsubst lib%,%,$(patsubst %.a,%,$(notdir $(n))))) -Wl,--end-group \
	-Wl,-Bdynamic \
	$(foreach y, $(LOCAL_SHARED_LIBS), -l$(patsubst lib%,%,$(patsubst %.so,%,$(notdir $(y)))))

#generate object files
OBJS := $(SRCCS:%=%.o) #OBJS=$(patsubst %,%.o,$(SRCCS))

#add dynamic lib name suffix and static lib name suffix.
target_dynamic := $(if $(LOCAL_TARGET_DYNAMIC),$(LOCAL_TARGET_DYNAMIC).so,)
target_static := $(if $(LOCAL_TARGET_STATIC),$(LOCAL_TARGET_STATIC).a,)

#generate exe file.
.PHONY: all
all: $(target_dynamic) $(target_static)
	-@mkdir -p $(INSTALL_PREFIX)/usr/lib
	install -m0755 $(target_dynamic) $(target_static) $(LIBISP_DIR)
	install -m0755 $(target_dynamic) $(target_static) $(INSTALL_PREFIX)/usr/lib
	@echo ===================================
	@echo build libisp-isp_ini done
	@echo ===================================

$(target_dynamic): $(OBJS)
	$(CC) $+ $(LOCAL_DYNAMIC_LDFLAGS) -o $@
	@echo ----------------------------
	@echo "finish target: $@"
#	@echo "object files:  $+"
#	@echo "source files:  $(SRCCS)"
	@echo ----------------------------

$(target_static): $(OBJS)
	$(AR) -rcs -o $@ $+
	@echo ----------------------------
	@echo "finish target: $@"
#	@echo "object files:  $+"
#	@echo "source files:  $(SRCCS)"
	@echo ----------------------------

#patten rules to generate local object files
%.cpp.o: %.cpp
	$(CXX) $(LOCAL_CXXFLAGS) $(LOCAL_CPPFLAGS) -MD -MP -MF $(patsubst %,%.d,$@) -c -o $@ $<

%.cc.o: %.cc
	$(CXX) $(LOCAL_CXXFLAGS) $(LOCAL_CPPFLAGS) -MD -MP -MF $(patsubst %,%.d,$@) -c -o $@ $<

%.c.o: %.c
	$(CC) $(LOCAL_CFLAGS) $(LOCAL_CPPFLAGS) -MD -MP -MF $(patsubst %,%.d,$@) -c -o $@ $<

# clean all
.PHONY: clean
clean:
	-rm -f $(OBJS) $(OBJS:%=%.d) $(target_dynamic) $(target_static)

#add *.h prerequisites
-include $(OBJS:%=%.d)

