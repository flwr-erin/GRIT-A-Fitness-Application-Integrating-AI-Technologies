import 'package:fitness_app/common/color_extension.dart';
import 'package:fitness_app/common/round_button.dart';
import 'package:fitness_app/view/login/Log_In.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class OnBoardingView extends StatefulWidget {
  const OnBoardingView({super.key});

  @override
  State<OnBoardingView> createState() => _OnBoardingViewState();
}

class _OnBoardingViewState extends State<OnBoardingView> {
  PageController? controller = PageController();
  int selectPage = 0;
  Timer? _timer;

  List pageArr = [
    {
      "title": "Have a good health",
      "subtitle":
          "Being healthy is all, no health is nothing.\nSo why do not we",
      "image": "assets/img/on_board_1.png",
    },
    {
      "title": "Be stronger",
      "subtitle":
          "Take 30 minutes of bodybuilding every day\nto get physically fit and healthy.",
      "image": "assets/img/on_board_2.png",
    },
    {
      "title": "Have nice body",
      "subtitle":
          "Bad body shape, poor sleep, lack of strength,\nweight gain, weak bones, easily traumatized\n body, depressed, stressed, poor metabolism,\n poor resistance",
      "image": "assets/img/on_board_3.png",
    }
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller?.addListener(() {
      selectPage = controller?.page?.round() ?? 0;

      if (mounted) {
        setState(() {});
      }
    });

    // Add auto-scroll timer
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (controller != null) {
        if (selectPage < pageArr.length - 1) {
          selectPage++;
        } else {
          selectPage = 0;
        }
        controller!.animateToPage(
          selectPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.sizeOf(context);
    return Scaffold(
        backgroundColor: TColor.primary,
        body: Stack(children: [
          Image.asset(
            'assets/img/on_board_bg.png',
            width: media.width,
            height: media.height,
            fit: BoxFit.cover,
          ),
          SafeArea(
              child: PageView.builder(
                  controller: controller,
                  itemCount: pageArr.length,
                  itemBuilder: (context, index) {
                    var p0bj = pageArr[index] as Map? ?? {};

                    return Column(
                      children: [
                        SizedBox(
                          height: media.width * 0.20,
                        ),
                        Text(
                          p0bj["title"].toString(),
                          style: TextStyle(
                              color: TColor.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(
                          height: media.width * 0.20,
                        ),
                        Image.asset(
                          p0bj["image"].toString(),
                          width: media.width * 0.8,
                          height: media.width * 0.8,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(
                          height: media.width * 0.35,
                        ),
                        Text(
                          p0bj["subtitle"].toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: TColor.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  })),
          SafeArea(
              child: Column(
            children: [
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: pageArr.map((p0bj) {
                  var index = pageArr.indexOf(p0bj);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: selectPage == index
                          ? TColor.white
                          : TColor.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }).toList(),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                child: RoundButton(
                  title: "Start",
                  type: RoundButtonType.primaryText,
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => LogInScreen()),
                        (route) => false);
                  },
                ),
              ),
              SizedBox(
                height: media.width * 0.07,
              ),
            ],
          ))
        ]));
  }
}
