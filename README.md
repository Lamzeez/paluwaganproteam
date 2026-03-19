PaluwaganPro
A modern Flutter application for managing digital paluwagan (rotating savings and credit associations) groups. Bring the traditional Filipino savings system into the digital age with transparent tracking, secure payments, and community management.

Features
User Authentication: Secure sign-up and login with password validation

Group Management: Create and join paluwagan groups with unique join codes

Payment System: GCash integration with payment proof uploads and verification

Real-time Tracking: Monitor contributions, payouts, and rotation schedules

Group Chat: Communicate with members within each group

Notifications: Get alerts for payments, verifications, and group updates

Profile Management: Update personal info and GCash details

Tech Stack
Flutter (frontend)

SQLite (local database with sqflite)

Provider (state management)

Image Picker (photo uploads)

Getting Started
Prerequisites
Flutter SDK (latest stable)

Dart SDK

Installation
Clone the repository

Run flutter pub get to install dependencies

Run flutter run to start the application

Database Schema
The app uses SQLite with tables for users, groups, members, contributions, transactions, chat messages, notifications, payment proofs, and round rotations. Database migrations are handled automatically on version upgrades.