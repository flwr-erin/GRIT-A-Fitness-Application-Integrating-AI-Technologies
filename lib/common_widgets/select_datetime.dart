import 'package:fitness_app/common/extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../common/color_extension.dart';

class SelectDatetime extends StatelessWidget {
  final DateTime? selectDate;
  final String? title;
  final Function(DateTime) didChange;
  const SelectDatetime(
      {super.key,
      required this.title,
      required this.didChange,
      this.selectDate});

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size; // Fix for MediaQuery
    return InkWell(
      onTap: () {
        showCupertinoModalPopup(
            context: context,
            builder: (context) {
              return Container(
                height: 270,
                color: TColor.white,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              "Done",
                              style: TextStyle(
                                  color: TColor.secondaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ))
                      ],
                    ),
                    SizedBox(
                      height: 200,
                      child: CupertinoDatePicker(
                          initialDateTime: selectDate,
                          dateOrder: DatePickerDateOrder.ymd,
                          mode: CupertinoDatePickerMode.date,
                          onDateTimeChanged: didChange),
                    )
                  ],
                ),
              );
            });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: media.width * 0.05),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Birthday",
              style: TextStyle(
                color: TColor.secondaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              selectDate == null
                  ? "Select Date"
                  : selectDate!.stringFormat(format: "MMM dd, yyyy"),
              style: TextStyle(
                color: TColor.primary,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
