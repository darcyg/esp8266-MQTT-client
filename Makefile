# tnx to mamalala
# Changelog
# Changed the variables to include the header file directory
# Added global var for the XTENSA tool root
#
# This make file still needs some work.
#
#
# Output directors to store intermediate compiled files
# relative to the project directory
BUILD_BASE	= build
FW_BASE		= firmware
FLAVOR = release

# Base directory for the compiler
XTENSA_TOOLS_ROOT ?= c:/Espressif/xtensa-lx106-elf/bin

#Extra Tensilica includes from the ESS VM
SDK_EXTRA_INCLUDES ?= c:/Espressif/ESP8266_SDK/include
SDK_EXTRA_LIBS ?= c:/Espressif/ESP8266_SDK/lib

# base directory of the ESP8266 SDK package, absolute
SDK_BASE	?= c:/Espressif/ESP8266_SDK

#Esptool.py path and port
PYTHON		?= C:\Python27\python.exe
ESPTOOL		?= c:\Espressif\utils\esptool.exe
#ESPTOOL		?= c:\Espressif\utils\esptool.py
ESPPORT		?= COM13

# name for the target project
TARGET		= httpd

# which modules (subdirectories) of the project to include in compiling
#MODULES		= driver mqtt user lwip/api lwip/app lwip/core lwip/core/ipv4 lwip/netif
MODULES		= driver mqtt user


EXTRA_INCDIR	= include $(SDK_BASE)/../include \
		. \
		lib/heatshrink/ \
		mqtt \
		$(SDK_EXTRA_INCLUDES) 
#		include\driver \


# libraries used in this project, mainly provided by the SDK
#LIBS		= c gcc hal phy pp net80211 wpa main lwip
LIBS		= c gcc hal phy pp net80211 lwip wpa upgrade main ssl

# compiler flags using during compilation of source files

#CFLAGS		= -Os -g -O2 -std=c99 -Werror -Wpointer-arith -Wundef -Wl,-EL -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals -D__ets__ -DICACHE_FLASH -Wno-address 
CFLAGS		= -Os -g -O2 -std=c99  -Wpointer-arith -Wundef -Wl,-EL -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals -D__ets__ -DICACHE_FLASH -Wno-address 

# linker flags used to generate the main object file
LDFLAGS		= -nostdlib -Wl,--no-check-sections -u call_user_start -Wl,-static

ifeq ($(FLAVOR),debug)
    CFLAGS += -g -O0
    LDFLAGS += -g -O0
endif

ifeq ($(FLAVOR),release)
    CFLAGS += -g -O2
    LDFLAGS += -g -O2
endif

# linker script used for the above linkier step
LD_SCRIPT	= eagle.app.v6.ld

# various paths from the SDK used in this project
SDK_LIBDIR	= lib
SDK_LDDIR	= ld
SDK_INCDIR	= include include/json

# we create two different files for uploading into the flash
# these are the names and options to generate them
FW_FILE_1	= 0x00000
FW_FILE_1_ARGS	= -bo $@ -bs .text -bs .data -bs .rodata -bc -ec
FW_FILE_2	= 0x40000
FW_FILE_2_ARGS	= -es .irom0.text $@ -ec

# select which tools to use as compiler, librarian and linker
CC		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-gcc
AR		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-ar
LD		:= $(XTENSA_TOOLS_ROOT)/xtensa-lx106-elf-gcc

####
#### no user configurable options below here
####
FW_TOOL		?= $(XTENSA_TOOLS_ROOT)/esptool
SRC_DIR		:= $(MODULES)
BUILD_DIR	:= $(addprefix $(BUILD_BASE)/,$(MODULES))

SDK_LIBDIR	:= $(addprefix $(SDK_BASE)/,$(SDK_LIBDIR))
SDK_INCDIR	:= $(addprefix -I$(SDK_BASE)/,$(SDK_INCDIR))

SRC		:= $(foreach sdir,$(SRC_DIR),$(wildcard $(sdir)/*.c))
OBJ		:= $(patsubst %.c,$(BUILD_BASE)/%.o,$(SRC))
LIBS		:= $(addprefix -l,$(LIBS))
APP_AR		:= $(addprefix $(BUILD_BASE)/,$(TARGET)_app.a)
TARGET_OUT	:= $(addprefix $(BUILD_BASE)/,$(TARGET).out)

LD_SCRIPT	:= $(addprefix -T$(SDK_BASE)/$(SDK_LDDIR)/,$(LD_SCRIPT))

INCDIR	:= $(addprefix -I,$(SRC_DIR))
EXTRA_INCDIR	:= $(addprefix -I,$(EXTRA_INCDIR))
MODULE_INCDIR	:= $(addsuffix /include,$(INCDIR))

FW_FILE_1	:= $(addprefix $(FW_BASE)/,$(FW_FILE_1).bin)
FW_FILE_2	:= $(addprefix $(FW_BASE)/,$(FW_FILE_2).bin)

V ?= $(VERBOSE)
ifeq ("$(V)","1")
Q :=
vecho := @true
else
Q := @
vecho := @echo
endif

vpath %.c $(SRC_DIR)

define compile-objects
$1/%.o: %.c
	$(vecho) "CC $$<"
	$(Q) $(CC) $(INCDIR) $(MODULE_INCDIR) $(EXTRA_INCDIR) $(SDK_INCDIR) $(CFLAGS)  -c $$< -o $$@
endef

.PHONY: all checkdirs clean

all: checkdirs $(TARGET_OUT) $(FW_FILE_1) $(FW_FILE_2)

$(FW_FILE_1): $(TARGET_OUT) firmware
	$(vecho) "FW $@"
	$(Q) $(FW_TOOL) -eo $(TARGET_OUT) $(FW_FILE_1_ARGS)

$(FW_FILE_2): $(TARGET_OUT) firmware
	$(vecho) "FW $@"
	$(Q) $(FW_TOOL) -eo $(TARGET_OUT) $(FW_FILE_2_ARGS)

$(TARGET_OUT): $(APP_AR)
	$(vecho) "LD $@"
	$(Q) $(LD) -L$(SDK_LIBDIR) $(LD_SCRIPT) $(LDFLAGS) -Wl,--start-group $(LIBS) $(APP_AR) -Wl,--end-group -o $@

$(APP_AR): $(OBJ)
	$(vecho) "AR $@"
	$(Q) $(AR) cru $@ $^

checkdirs: $(BUILD_DIR) $(FW_BASE)

$(BUILD_DIR):
	$(Q) mkdir -p $@

firmware:
	$(Q) mkdir -p $@

flash: $(FW_FILE_1) $(FW_FILE_2)
	$(ESPTOOL) -p $(ESPPORT) write_flash 0x00000 firmware/0x00000.bin 0x40000 firmware/0x40000.bin 0x12000 webpages.espfs
#	$(PYTHON) $(ESPTOOL) -p $(ESPPORT) write_flash 0x00000 firmware/0x00000.bin 0x40000 firmware/0x40000.bin 0x12000 webpages.espfs
#	$(PYTHON) $(ESPTOOL) -p $(ESPPORT) write_flash 0x00000 firmware/0x00000.bin 0x40000 firmware/0x40000.bin

blank512k: firmware/0x00000.bin firmware/0x40000.bin
	$(ESPTOOL) -p $(ESPPORT) write_flash 0x00000 blank/blank512k.bin


flash_webpages: $(FW_FILE_1) $(FW_FILE_2)
#	$(PYTHON) $(ESPTOOL) -p $(ESPPORT) write_flash 0x12000 webpages.espfs
	$(ESPTOOL) -p $(ESPTOOL) -p $(ESPPORT) write_flash 0x12000 webpages.espfs
	 
Make_webpages.espfs: mkespfsimage/mkespfsimage
	cd html 
	C:\cygwin64\bin\find * | C:\Espressif\examples\esphttpd\mkespfsimage > ..\webpages.espfs
	cd ..

mkespfsimage/mkespfsimage: mkespfsimage/
	make -C mkespfsimage/mman-win32
#	make -C mkespfsimage -f Makefile.windows
	make -C mkespfsimage -f Makefile

htmlflash: webpages.espfs
	if [ $$(stat -c '%s' webpages.espfs) -gt $$(( 0x2E000 )) ]; then echo "webpages.espfs too big!"; false; fi
	$(ESPTOOL) -p $(ESPPORT) write_flash 0x12000 webpages.espfs

clean:
	$(Q) rm -f $(APP_AR)
	$(Q) rm -f $(TARGET_OUT)
	$(Q) find $(BUILD_BASE) -type f | xargs rm -f
	$(Q) rm -rf $(BUILD_BASE)
	$(Q) rm -f $(FW_FILE_1)
	$(Q) rm -f $(FW_FILE_2)
	$(Q) rm -rf $(FW_BASE)

$(foreach bdir,$(BUILD_DIR),$(eval $(call compile-objects,$(bdir))))
