# Scene It Virtual Camera Plugin Makefile
#
# Builds the CoreMediaIO DAL plugin

PLUGIN_NAME = SceneItVirtualCamera
PLUGIN_BUNDLE = $(PLUGIN_NAME).plugin
PLUGIN_EXECUTABLE = $(PLUGIN_BUNDLE)/Contents/MacOS/$(PLUGIN_NAME)

# Compiler settings
CXX = clang++
CXXFLAGS = -std=c++11 -arch x86_64 -arch arm64 -mmacosx-version-min=13.0
CXXFLAGS += -fPIC -fvisibility=hidden -fvisibility-inlines-hidden
CXXFLAGS += -Wall -Wextra -Werror -O2 -DNDEBUG

# Frameworks and libraries
FRAMEWORKS = -framework CoreFoundation -framework CoreMediaIO -framework CoreVideo -framework CoreMedia
LIBRARIES = -lpthread

# Source files
SOURCES = SceneItVirtualCamera.cpp
OBJECTS = $(SOURCES:.cpp=.o)

# Include paths
INCLUDES = -I. -I../Resources

# Build rules
all: $(PLUGIN_EXECUTABLE)

$(PLUGIN_EXECUTABLE): $(OBJECTS) | $(PLUGIN_BUNDLE)/Contents/MacOS
	$(CXX) $(CXXFLAGS) $(FRAMEWORKS) $(LIBRARIES) -bundle -o $@ $(OBJECTS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(PLUGIN_BUNDLE)/Contents/MacOS:
	mkdir -p $(PLUGIN_BUNDLE)/Contents/MacOS

clean:
	rm -rf $(OBJECTS) $(PLUGIN_BUNDLE)/Contents/MacOS/$(PLUGIN_NAME)

install: $(PLUGIN_EXECUTABLE)
	@echo "Installing plugin to ~/Library/CoreMediaIO/Plug-Ins/DAL/"
	mkdir -p ~/Library/CoreMediaIO/Plug-Ins/DAL/
	cp -R $(PLUGIN_BUNDLE) ~/Library/CoreMediaIO/Plug-Ins/DAL/
	@echo "Plugin installed. Restart applications to detect new camera."

uninstall:
	@echo "Removing plugin from ~/Library/CoreMediaIO/Plug-Ins/DAL/"
	rm -rf ~/Library/CoreMediaIO/Plug-Ins/DAL/$(PLUGIN_BUNDLE)
	@echo "Plugin removed. Restart applications to complete removal."

codesign: $(PLUGIN_EXECUTABLE)
	codesign --sign "Developer ID Application" --timestamp $(PLUGIN_BUNDLE)

.PHONY: all clean install uninstall codesign