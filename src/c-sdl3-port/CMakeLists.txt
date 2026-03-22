cmake_minimum_required(VERSION 3.20)
project(wolf3d LANGUAGES C)

# ---------------------------------------------------------------------------
# SDL3 via FetchContent
# ---------------------------------------------------------------------------
include(FetchContent)
FetchContent_Declare(
    SDL3
    GIT_REPOSITORY https://github.com/libsdl-org/SDL.git
    GIT_TAG        release-3.2.14
    GIT_SHALLOW    TRUE
)
# Build SDL3 as a static library so the executable is self-contained
set(SDL_STATIC ON  CACHE BOOL "" FORCE)
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(SDL3)

# ---------------------------------------------------------------------------
# C standard
# ---------------------------------------------------------------------------
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# ---------------------------------------------------------------------------
# Source files
#
# All .C files in this directory EXCEPT:
#   CONTIGSC.C  - DOS conventional-memory helper, not needed
#   DETECT.C    - DOS CPU detection, not needed
#   MUNGE.C     - standalone utility, not part of the game
#   OLDSCALE.C  - unused legacy scaler
#   WOLFHACK.C  - DOS asm helper, replaced by C ports
#
# The *_A.C files (WL_ASM.C, WL_DR_A.C, ID_VL_A.C, ID_VH_A.C, ID_US_A.C)
# are C replacements for the original .ASM files.
# ---------------------------------------------------------------------------
set(WOLF3D_SOURCES
    # -- Id Engine --
    ID_CA.C
    ID_IN.C
    ID_MM.C
    ID_PM.C
    ID_SD.C
    ID_US_1.C
    ID_VH.C
    ID_VL.C

    # -- ASM replacements (C ports) --
    ID_US_A.C
    ID_VH_A.C
    ID_VL_A.C
    WL_ASM.C
    WL_DR_A.C

    # -- Game logic --
    WL_ACT1.C
    WL_ACT2.C
    WL_AGENT.C
    WL_DEBUG.C
    WL_DRAW.C
    WL_GAME.C
    WL_INTER.C
    WL_MAIN.C
    WL_MENU.C
    WL_PLAY.C
    WL_SCALE.C
    WL_STATE.C
    WL_TEXT.C
)

# ---------------------------------------------------------------------------
# Signon screen stub
#
# The original build linked SIGNON.OBJ (a raw 64000-byte VGA signon bitmap)
# and GAMEPAL.OBJ (the 768-byte palette).  These were pre-built object files,
# not C source.  We provide a minimal C stub that defines the symbol so the
# linker is happy.  The signon screen will be blank (zeroed); replace the
# array contents with real data if you have it.
# ---------------------------------------------------------------------------
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/signon_stub.c")
    file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/signon_stub.c"
"/* Stub for signon screen data (originally SIGNON.OBJ + GAMEPAL.OBJ) */\n\
/* The original was a 64000-byte raw VGA Mode 13h bitmap.              */\n\
/* Replace this with real data extracted from the OBJ if desired.      */\n\
char signon[64000] = {0};\n"
    )
endif()
list(APPEND WOLF3D_SOURCES signon_stub.c)

# CMake treats .C (uppercase) as C++ on some platforms.  Force all .C files
# to compile as C.
set_source_files_properties(${WOLF3D_SOURCES} PROPERTIES LANGUAGE C)

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------
add_executable(wolf3d ${WOLF3D_SOURCES})

# ---------------------------------------------------------------------------
# Include path (find headers in the source directory)
# ---------------------------------------------------------------------------
target_include_directories(wolf3d PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# ---------------------------------------------------------------------------
# Preprocessor defines
# ---------------------------------------------------------------------------
target_compile_definitions(wolf3d PRIVATE
    # GOODTIMES and CARMACIZED are already defined in VERSION.H.
    # Add any additional defines here as needed.
    # If VERSION.H is changed, uncomment these:
    # GOODTIMES
    # CARMACIZED
)

if(WIN32)
    target_compile_definitions(wolf3d PRIVATE WIN32_LEAN_AND_MEAN)
endif()

# ---------------------------------------------------------------------------
# Link SDL3
# ---------------------------------------------------------------------------
target_link_libraries(wolf3d PRIVATE SDL3::SDL3)

# On Windows, also link SDL3::SDL3main so SDL can provide WinMain if needed
if(TARGET SDL3::SDL3main)
    target_link_libraries(wolf3d PRIVATE SDL3::SDL3main)
endif()

# ---------------------------------------------------------------------------
# Compiler warnings — keep it buildable but informative
# ---------------------------------------------------------------------------
if(MSVC)
    target_compile_options(wolf3d PRIVATE /W3 /wd4996)
else()
    target_compile_options(wolf3d PRIVATE -Wall -Wno-unused-variable -Wno-unused-but-set-variable)
endif()

# ---------------------------------------------------------------------------
# Game data files (*.WL6)
#
# Wolf3D expects these files in the working directory at runtime:
#   AUDIOHED.WL6  AUDIOT.WL6  CONFIG.WL6  GAMEMAPS.WL6
#   MAPHEAD.WL6   VGADICT.WL6 VGAGRAPH.WL6 VGAHEAD.WL6  VSWAP.WL6
#
# Set WOLF3D_DATA_DIR to the folder containing the WL6 files.
# They will be copied next to the executable as a post-build step.
# Example:  cmake -DWOLF3D_DATA_DIR="C:/games/wolf3d" ..
# ---------------------------------------------------------------------------
set(WOLF3D_DATA_DIR "" CACHE PATH "Directory containing *.WL6 game data files")

if(WOLF3D_DATA_DIR)
    file(GLOB WL6_FILES "${WOLF3D_DATA_DIR}/*.WL6")
    if(WL6_FILES)
        foreach(DATA_FILE ${WL6_FILES})
            get_filename_component(FNAME ${DATA_FILE} NAME)
            add_custom_command(TARGET wolf3d POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${DATA_FILE}"
                    "$<TARGET_FILE_DIR:wolf3d>/${FNAME}"
                COMMENT "Copying ${FNAME} to build directory"
            )
        endforeach()
    else()
        message(WARNING "WOLF3D_DATA_DIR is set but no *.WL6 files found in: ${WOLF3D_DATA_DIR}")
    endif()
else()
    message(STATUS "WOLF3D_DATA_DIR not set. You will need to copy *.WL6 files to the build output directory manually.")
endif()
