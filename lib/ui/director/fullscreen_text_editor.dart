import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:flutter_video_editor_app/service/director_service.dart';
import 'package:flutter_video_editor_app/service_locator.dart';
import 'package:flutter_video_editor_app/ui/director/text_form.dart';

enum TextEditingMode { none, textColor, fontSize, backgroundColor }

class FullScreenTextEditor extends StatefulWidget {
  final Asset? asset;
  final VoidCallback? onClose;

  const FullScreenTextEditor({Key? key, this.asset, this.onClose})
    : super(key: key);

  @override
  State<FullScreenTextEditor> createState() => _FullScreenTextEditorState();
}

class _FullScreenTextEditorState extends State<FullScreenTextEditor> {
  final directorService = locator.get<DirectorService>();
  late TextEditingController _textController;
  late FocusNode _focusNode;

  // Text style options
  List<Color> _textColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.cyan,
  ];

  List<Color> _backgroundColors = [
    Colors.transparent,
    Color(0x88000000), // Asset model default - semi-transparent black
    Colors.black.withOpacity(0.7),
    Colors.white.withOpacity(0.7),
    Colors.red.withOpacity(0.7),
    Colors.blue.withOpacity(0.7),
    Colors.green.withOpacity(0.7),
    Colors.yellow.withOpacity(0.7),
    Colors.purple.withOpacity(0.7),
  ];

  List<String> _fontFamilies = [
    'Lato/Lato-Regular.ttf', // Asset model default
    'Roboto/Roboto-Regular.ttf',
    'Open_Sans/OpenSans-Regular.ttf',
    'Pacifico/Pacifico-Regular.ttf',
    'Lobster/Lobster-Regular.ttf',
    'Dancing_Script/DancingScript-Regular.ttf',
  ];

  int _selectedColorIndex = 0;
  int _selectedBackgroundIndex = 0;
  int _selectedFontIndex = 0;
  double _fontSize = 0.08;
  TextAlign _textAlign = TextAlign.center;
  TextEditingMode _currentEditingMode = TextEditingMode.none;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    if (widget.asset != null) {
      _textController.text = widget.asset!.title;
      _fontSize = widget.asset!.fontSize;
      _selectedColorIndex = _findColorIndex(widget.asset!.fontColor);
      _selectedBackgroundIndex = _findBackgroundColorIndex(
        widget.asset!.boxcolor,
      );
      _selectedFontIndex = _findFontIndex(widget.asset!.font);
    } else {
      // Default values for new text (matching Asset constructor defaults)
      _textController.text = '';
      _fontSize = 0.1; // Asset default
      _selectedColorIndex = 0; // White (0xFFFFFFFF)
      _selectedBackgroundIndex = 1; // Semi-transparent black (0x88000000)
      _selectedFontIndex = 0; // Lato font
    }

    // Auto focus when opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _findColorIndex(int color) {
    for (int i = 0; i < _textColors.length; i++) {
      if (_textColors[i].value == color) return i;
    }
    return 0;
  }

  int _findBackgroundColorIndex(int color) {
    for (int i = 0; i < _backgroundColors.length; i++) {
      if (_backgroundColors[i].value == color) return i;
    }
    return 0;
  }

  int _findFontIndex(String font) {
    for (int i = 0; i < _fontFamilies.length; i++) {
      if (_fontFamilies[i] == font) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors
          .black, // Completely opaque background to hide underlying interface
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Top bar
                _buildTopBar(),

                // Flexible content area
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Text input area (centered)
                      Flexible(
                        flex: 2,
                        child: Center(child: _buildTextInputArea()),
                      ),

                      // Options display area (above buttons)
                      Flexible(flex: 1, child: _buildOptionsArea()),
                    ],
                  ),
                ),

                // Bottom buttons (always visible)
                _buildBottomButtons(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () {
              _cancelEdit();
            },
          ),
          const Text(
            'Text',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white, size: 28),
            onPressed: _saveText,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsArea() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: _currentEditingMode == TextEditingMode.none
            ? 60
            : 160, // Constrain max height
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(
          0.4,
        ), // Slightly more opaque for options
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: _buildCurrentModeOptions(),
    );
  }

  Widget _buildTextInputArea() {
    Font font = Font.getByPath(_fontFamilies[_selectedFontIndex]);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 60,
        maxHeight:
            MediaQuery.of(context).size.height * 0.25, // Reduced max height
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          textAlign: _textAlign,
          maxLines: null,
          style: TextStyle(
            fontSize: _fontSize * MediaQuery.of(context).size.width,
            color: _textColors[_selectedColorIndex],
            backgroundColor: _backgroundColors[_selectedBackgroundIndex],
            fontFamily: font.family,
            fontWeight: font.weight,
            fontStyle: font.style,
            height: 1.3,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Click to edit text',
            hintStyle: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: EdgeInsets.all(16),
          ),
          cursorColor: Colors.white,
          cursorWidth: 2,
          onChanged: (text) {
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      constraints: BoxConstraints(minHeight: 60, maxHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(
          0.5,
        ), // More opaque for better visibility
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: _buildEditingModeSelector(),
    );
  }

  Widget _buildEditingModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeButton(
            mode: TextEditingMode.textColor,
            label: 'Text Color',
            icon: Icons.text_format,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeButton(
            mode: TextEditingMode.fontSize,
            label: 'Font Size',
            icon: Icons.text_fields,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModeButton(
            mode: TextEditingMode.backgroundColor,
            label: 'Background',
            icon: Icons.crop_square,
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required TextEditingMode mode,
    required String label,
    required IconData icon,
  }) {
    final isActive = _currentEditingMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle off if already active, otherwise set to this mode
          _currentEditingMode = isActive ? TextEditingMode.none : mode;
        });
      },
      child: Container(
        constraints: BoxConstraints(
          minHeight: 40,
        ), // Ensure minimum touch target
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: Colors.white.withOpacity(0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white60,
              size: 16,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentModeOptions() {
    switch (_currentEditingMode) {
      case TextEditingMode.none:
        return SizedBox.shrink();
      case TextEditingMode.textColor:
        return _buildTextColorOptions();
      case TextEditingMode.fontSize:
        return _buildFontSizeOptions();
      case TextEditingMode.backgroundColor:
        return _buildBackgroundColorOptions();
    }
  }

  Widget _buildTextColorOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Text Color',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _textColors.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorIndex = index;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _textColors[index] == Colors.transparent
                          ? Colors.white24
                          : _textColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColorIndex == index
                            ? Colors.white
                            : Colors.white30,
                        width: _selectedColorIndex == index ? 3 : 1,
                      ),
                      boxShadow: _selectedColorIndex == index
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: _textColors[index] == Colors.transparent
                        ? const Icon(
                            Icons.format_color_reset,
                            color: Colors.white54,
                            size: 20,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFontSizeOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Font Size & Style',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.text_fields, color: Colors.white54, size: 18),
            Expanded(
              child: Slider(
                value: _fontSize,
                min: 0.03,
                max: 0.15,
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
                thumbColor: Colors.white,
                onChanged: (value) {
                  setState(() {
                    _fontSize = value;
                  });
                },
              ),
            ),
            const Icon(Icons.text_fields, color: Colors.white54, size: 28),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Font',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _fontFamilies.length,
                        itemBuilder: (context, index) {
                          Font font = Font.getByPath(_fontFamilies[index]);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFontIndex = index;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _selectedFontIndex == index
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedFontIndex == index
                                      ? Colors.white30
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                font.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontFamily: font.family,
                                  fontWeight: font.weight,
                                  fontStyle: font.style,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleTextAlign,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getAlignmentIcon(), color: Colors.white, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        _getAlignmentText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundColorOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Background Color',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _backgroundColors.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBackgroundIndex = index;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _backgroundColors[index] == Colors.transparent
                          ? Colors.white24
                          : _backgroundColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedBackgroundIndex == index
                            ? Colors.white
                            : Colors.white30,
                        width: _selectedBackgroundIndex == index ? 3 : 1,
                      ),
                      boxShadow: _selectedBackgroundIndex == index
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: _backgroundColors[index] == Colors.transparent
                        ? const Icon(
                            Icons.format_color_reset,
                            color: Colors.white54,
                            size: 20,
                          )
                        : const Icon(
                            Icons.crop_square,
                            color: Colors.white54,
                            size: 20,
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  IconData _getAlignmentIcon() {
    switch (_textAlign) {
      case TextAlign.left:
        return Icons.format_align_left;
      case TextAlign.center:
        return Icons.format_align_center;
      case TextAlign.right:
        return Icons.format_align_right;
      default:
        return Icons.format_align_center;
    }
  }

  String _getAlignmentText() {
    switch (_textAlign) {
      case TextAlign.left:
        return 'Left';
      case TextAlign.center:
        return 'Center';
      case TextAlign.right:
        return 'Right';
      default:
        return 'Center';
    }
  }

  void _toggleTextAlign() {
    setState(() {
      switch (_textAlign) {
        case TextAlign.left:
          _textAlign = TextAlign.center;
          break;
        case TextAlign.center:
          _textAlign = TextAlign.right;
          break;
        case TextAlign.right:
          _textAlign = TextAlign.left;
          break;
        default:
          _textAlign = TextAlign.center;
      }
    });
  }

  void _saveText() {
    if (_textController.text.trim().isEmpty) {
      // If empty text, just close without saving
      if (widget.onClose != null) widget.onClose!();
      return;
    }

    if (widget.asset != null) {
      // Update the current editing asset with new values
      widget.asset!.title = _textController.text;
      widget.asset!.fontSize = _fontSize;
      widget.asset!.fontColor = _textColors[_selectedColorIndex].value;
      widget.asset!.boxcolor =
          _backgroundColors[_selectedBackgroundIndex].value;
      widget.asset!.font = _fontFamilies[_selectedFontIndex];

      // Use the existing saveTextAsset method from DirectorService
      // This handles adding to timeline and triggering layer changes properly
      directorService.saveTextAsset();
    }

    if (widget.onClose != null) widget.onClose!();
  }

  void _cancelEdit() {
    // If we're editing an existing asset and it was already in the timeline,
    // just close without any changes
    if (widget.asset != null &&
        directorService.layers.length > 1 &&
        directorService.layers[1].assets.contains(widget.asset!)) {
      // This is editing an existing asset - just close
      directorService.editingTextAsset = null;
    } else {
      // This might be a new asset that was created but not saved
      // Just close and let DirectorService handle cleanup
      directorService.editingTextAsset = null;
    }

    if (widget.onClose != null) widget.onClose!();
  }
}
