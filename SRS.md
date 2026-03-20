# Software Requirements Specification (SRS)
## Project: Paluwagan Pro
**Version:** 1.0  
**Date:** March 20, 2026  
**Company:** Paluwagan Pro LLC

---

## 1. Introduction
### 1.1 Purpose
The purpose of this document is to provide a detailed overview of the Paluwagan Pro application, its requirements, and its implementation details. This document serves as a guide for stakeholders, developers, and testers.

### 1.2 Scope
Paluwagan Pro is a Flutter-based mobile application designed to modernize and automate the traditional "Paluwagan" (Rotating Savings and Credit Association) system. It provides a secure, real-time platform for users to create savings groups, manage contributions, and ensure transparent payout rotations.

### 1.3 Definitions, Acronyms, and Abbreviations
*   **ROSCA:** Rotating Savings and Credit Association.
*   **RLS:** Row Level Security (Supabase/PostgreSQL feature).
*   **RPC:** Remote Procedure Call.
*   **Honey Pot:** The automated fee and savings deduction logic.

---

## 2. Overall Description
### 2.1 Product Perspective
Paluwagan Pro is a standalone mobile application that leverages Supabase as its backend-as-a-service (BaaS). It uses real-time database streams to provide a live, collaborative experience similar to modern fintech apps.

### 2.2 Product Functions
*   **User Authentication:** Secure signup and login via email.
*   **Group Management:** Creation and deletion of savings groups.
*   **Join System:** Secure entry into groups via unique 6-digit alphanumeric codes.
*   **Real-time Dashboard:** Live updates of member counts, total pot, and upcoming payments.
*   **Financial Automation:** Automated fee deduction and cycle completion refunds.
*   **Communication:** Integrated real-time group chat for member coordination.

### 2.3 User Classes and Characteristics
*   **Group Creator:** Manages group settings, starts the rotation, and verifies member payments.
*   **Member:** Joins groups, submits payment proofs, and receives payouts.

---

## 3. System Features
### 3.1 Real-Time Data Synchronization
*   **Description:** Every screen (Dashboard, Group Detail, Chat) updates instantly without manual refresh.
*   **Requirement:** Use Supabase Realtime Streams to broadcast changes to the `groups`, `group_members`, and `group_chat` tables.

### 3.2 Randomized Rotation Logic
*   **Description:** To ensure fairness, the payout order is randomized only when the group is full and started by the creator.
*   **Requirement:** Implement a shuffle algorithm on the member list before generating the `round_rotations` schedule.

### 3.3 The "Honey Pot" Fee System (Phase 5.2)
*   **Description:** A 20% total fee is managed by the system.
*   **Logic:**
    *   **10% Admin Fee:** Automatically sent to the Creator's ledger upon verification.
    *   **10% Held Savings:** Retained by the system until the cycle is complete.
    *   **Refund:** Upon completion of the final round, all 10% held savings are returned to the respective members.

### 3.4 Payment Verification
*   **Description:** Users upload GCash screenshots as proof. Creators must verify these proofs to advance the round.
*   **Requirement:** Cascading updates from `payment_proofs` to `contributions` and then to `groups` member counts.

---

## 4. External Interface Requirements
### 4.1 User Interfaces
*   **Theme:** Modern Material 3 Design with a Primary Blue (#2563EB) color scheme.
*   **Navigation:** Bottom navigation bar for Home, Notifications, Create, Join, and Profile.

### 4.2 Software Interfaces
*   **Frontend:** Flutter SDK (^3.10.0).
*   **Backend:** Supabase (PostgreSQL, Storage, Realtime).
*   **Local Storage:** SQLite (via sqflite) for offline-first data caching.

---

## 5. Non-Functional Requirements
### 5.1 Security (Row Level Security)
*   **Requirement:** Users must only be able to see groups they have joined.
*   **Implementation:** PostgreSQL RLS policies ensuring `SELECT` is restricted to `auth.uid() IN (member_list)`.
*   **Bypass Logic:** A `SECURITY DEFINER` function (`find_group_by_code`) allows searching for groups by code without exposing the entire database.

### 5.2 Reliability
*   **Database Triggers:** Automatic member counting using server-side triggers to prevent "race conditions" where two users join at the same time.

### 5.3 Scalability
*   The system is built to handle multiple simultaneous Paluwagan cycles across thousands of users using Supabase's scalable cloud infrastructure.

---

## 6. Architectural Design
### 6.1 Data Model
*   **Groups Table:** Tracks pot size, contribution amount, and current round.
*   **Members Table:** Tracks status, rotation order, and participation.
*   **Transactions Table:** Immutable log of all `contribution`, `fee_creator`, `held_savings`, and `held_refund` events.

### 6.2 ViewModel Pattern
*   Uses the **Provider** package for state management.
*   `GroupsViewModel` acts as the orchestrator between `SupabaseService` and the UI.
