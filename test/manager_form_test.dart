import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/screens/admin/create_delivery_screen.dart';
void main(){
 testWidgets('empty eligible directory disables assignment',(tester)async{
  tester.view.physicalSize=const Size(1080,2200);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home:CreateDeliveryScreen(drivers:[])));
  expect(find.text('No on-shift drivers available'),findsOneWidget);
  final button=tester.widget<FilledButton>(find.byType(FilledButton));expect(button.onPressed,isNull);
 });
 testWidgets('form rejects missing recipient and invalid destination coordinates',(tester)async{
  tester.view.physicalSize=const Size(1080,2200);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home:CreateDeliveryScreen(drivers:[EligibleDriver(id:'uid',name:'Driver',status:'On Shift')])));
  final button=find.text('Create and assign');await tester.ensureVisible(button);await tester.tap(button);await tester.pump();
  expect(find.text('Enter a valid coordinate'),findsNWidgets(2));
  expect(find.text('Driver assignment is required'),findsOneWidget);
  await tester.drag(find.byType(ListView),const Offset(0,1500));await tester.pump();
  expect(find.text('Recipient name is required'),findsOneWidget);
 });
}
