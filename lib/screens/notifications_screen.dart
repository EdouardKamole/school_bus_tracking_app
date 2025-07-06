// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  // Mock data - replace with real data from Firebase later
  final List<NotificationModel> notifications = [
    NotificationModel(
      id: '1',
      title: 'Bus Arriving Soon',
      message: 'Your bus will arrive in 10 minutes',
      time: DateTime.now().subtract(Duration(minutes: 5)),
      isRead: false,
    ),
    NotificationModel(
      id: '2',
      title: 'Delay Notice',
      message: 'Bus is delayed by 15 minutes due to traffic',
      time: DateTime.now().subtract(Duration(hours: 2)),
      isRead: true,
    ),
    NotificationModel(
      id: '3',
      title: 'Route Update',
      message: 'Route has been slightly modified. See details in app.',
      time: DateTime.now().subtract(Duration(days: 1)),
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          TextButton(
            child: Text('Mark all as read', style: TextStyle(color: Colors.white)),
            onPressed: () {
              // Implement mark all as read functionality
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: notification.isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: Icon(
          Icons.notifications,
          color: notification.isRead ? Colors.grey : Colors.blue,
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            SizedBox(height: 5),
            Text(
              DateFormat('MMM dd, hh:mm a').format(notification.time),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: notification.isRead ? null : Icon(Icons.circle, size: 10, color: Colors.blue),
        onTap: () {
          // Handle notification tap
        },
      ),
    );
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
  });
}