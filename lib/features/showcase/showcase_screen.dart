import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  int _selectedModelIndex = 0;

  final List<Map<String, dynamic>> _models = [
    {
      'name': 'PROTO_UNIT_01',
      'asset': 'assets/images/duck_character_1.png',
      'color': const Color(0xFF00FFFF), // Cyan
      'filter': null,
    },
    {
      'name': 'BETA_STRIKER_02',
      'asset': 'assets/images/duck_character_2.png',
      'color': const Color(0xFFFF00FF), // Magenta
      'filter': null,
    },
    {
      'name': 'HEAVY_MECH_03',
      'asset': 'assets/images/duck_character_3.png',
      'color': const Color(0xFF00FFCC), // Mint/Neon Green
      'filter': null,
    },
    {
      'name': 'SHADOW_GLITCH_04',
      'asset': 'assets/images/duck_character_1.png',
      'color': Colors.purpleAccent,
      'filter': Colors.purpleAccent,
    },
    {
      'name': 'BIO_HAZARD_05',
      'asset': 'assets/images/duck_character_2.png',
      'color': Colors.lightGreenAccent,
      'filter': Colors.lightGreen,
    },
  ];

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _hoverAnimation = Tween<double>(begin: -15.0, end: 15.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeModel = _models[_selectedModelIndex];
    final activeColor = activeModel['color'] as Color;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        textTheme: GoogleFonts.spaceGroteskTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: activeColor,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'DUCK_RUNNER_2049',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: activeColor,
              shadows: [
                Shadow(color: activeColor, blurRadius: 10),
              ],
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Character Display Box
              Expanded(
                flex: 5,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _hoverAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _hoverAnimation.value),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: activeColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withOpacity(0.3),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: activeColor.withOpacity(0.1),
                            blurRadius: 100,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: activeModel['filter'] != null
                              ? ColorFiltered(
                                  colorFilter: ColorFilter.mode(activeModel['filter'] as Color, BlendMode.modulate),
                                  child: Image.asset(activeModel['asset'], fit: BoxFit.contain),
                                )
                              : Image.asset(activeModel['asset'], fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. System Log
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    border: Border.all(color: activeColor.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYSTEM_LOG //',
                        style: TextStyle(color: activeColor, fontSize: 12, letterSpacing: 2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'MODEL: ${activeModel['name']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeColor,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: activeColor, blurRadius: 5)],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('STATUS: HOVERING', style: TextStyle(letterSpacing: 1)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Select Character Model
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT_CHARACTER_MODEL',
                    style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    final isSelected = _selectedModelIndex == index;
                    final color = model['color'] as Color;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedModelIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 80,
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)]
                              : [],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: model['filter'] != null
                              ? ColorFiltered(
                                  colorFilter: ColorFilter.mode(model['filter'] as Color, BlendMode.modulate),
                                  child: Image.asset(model['asset']),
                                )
                              : Image.asset(model['asset']),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 4. Spec Board
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSpecItem('FRAME RATE', '60 FPS', activeColor),
                    _buildSpecItem('PHYSICS', 'G-FORCE 2.0', activeColor),
                    _buildSpecItem('LOCATION', 'SECTOR 7', activeColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
