import 'package:flutter/material.dart';
import 'package:fitness_app/common/color_extension.dart';
import 'dart:async';

class ExerciseDetailView extends StatefulWidget {
  final Map<String, dynamic> exercise;

  ExerciseDetailView({required this.exercise});

  @override
  _ExerciseDetailViewState createState() => _ExerciseDetailViewState();
}

class _ExerciseDetailViewState extends State<ExerciseDetailView> {
  bool _showFirstImage = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 1000), (Timer timer) {
      setState(() {
        _showFirstImage = !_showFirstImage;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.exercise['name']}',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: TColor.primary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: _showFirstImage ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 500),
                    child: Container(
                      margin: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: TColor.primary.withOpacity(0.3),
                            blurRadius: 15.0,
                            spreadRadius: 2.0,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/json/img/${widget.exercise['images'][0]}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _showFirstImage ? 0.0 : 1.0,
                    duration: Duration(milliseconds: 500),
                    child: Container(
                      margin: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: TColor.primary.withOpacity(0.3),
                            blurRadius: 15.0,
                            spreadRadius: 2.0,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/json/img/${widget.exercise['images'][1]}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.exercise['category'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                TColor.primary.withOpacity(0.4),
                                TColor.primary.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: TColor.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                '${widget.exercise['category']}'.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 12,
                                  shadows: [
                                    Shadow(
                                      color: TColor.primary.withOpacity(0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.exercise['primaryMuscles'] != null &&
                        widget.exercise['primaryMuscles'].isNotEmpty)
                      ...widget.exercise['primaryMuscles']
                          .map(
                            (muscle) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      TColor.primary.withOpacity(0.4),
                                      TColor.primary.withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: TColor.primary.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text(
                                      muscle.toString().toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'Quicksand',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 12,
                                        shadows: [
                                          Shadow(
                                            color:
                                                TColor.primary.withOpacity(0.3),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    if (widget.exercise['secondaryMuscles'] != null &&
                        widget.exercise['secondaryMuscles'].isNotEmpty)
                      ...widget.exercise['secondaryMuscles']
                          .map(
                            (muscle) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      TColor.primary.withOpacity(0.4),
                                      TColor.primary.withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: TColor.primary.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text(
                                      muscle.toString().toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'Quicksand',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 12,
                                        shadows: [
                                          Shadow(
                                            color:
                                                TColor.primary.withOpacity(0.3),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions:',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Quicksand')),
                  SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: widget.exercise['instructions'].length,
                    itemBuilder: (context, index) {
                      String instruction =
                          widget.exercise['instructions'][index];
                      if (instruction.isEmpty) return SizedBox.shrink();

                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 8.0),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TColor.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: TColor.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: TColor.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Quicksand',
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                instruction,
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
