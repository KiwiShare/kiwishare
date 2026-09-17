# System Architecture & Native Mobile Integrations

This document describes the high-level system architecture, database schema design, and native device integrations for the **KiwiShare** platform.

---

## 1. High-Level Architecture Overview

KiwiShare utilizes a decoupled client-server architecture hosted in a unified monorepo. Rather than relying purely on serverless Cloud Functions, KiwiShare runs a full, standalone **Node.js / Koa.js TypeScript RESTful Backend** backed by a dedicated **MongoDB** database:

```mermaid
graph TD
    subgraph Client Tier
        MobileApp[Flutter Mobile Client - Android / iOS]
        WebApp[Web Portal Client]
    end

    subgraph Backend Service Tier
        KoaApp[Koa.js TypeScript RESTful API Server]
        AuthRouter[Auth & OTP Sub-Router]
        UsedItemsRouter[UsedItems & Listings REST Router]
        TxRouter[Transactions & QR Handover Router]
        UsersRouter[User Profiles Sub-Router]
        MongooseODM[Mongoose ODM Layer]
    end

    subgraph Database & Persistence Tier
        MongoDB[(MongoDB Database - Primary Data Store)]
    end

    subgraph Supporting Cloud Services
        FirebaseAuth[Firebase Auth & Google OAuth Verification]
        FirebaseStorage[(Firebase Cloud Storage - Image Binaries)]
        FCM[Firebase Cloud Messaging - Push Notifications]
    end

    MobileApp -->|RESTful HTTPS / JSON| KoaApp
    WebApp -->|RESTful HTTPS / JSON| KoaApp

    KoaApp --> AuthRouter
    KoaApp --> UsedItemsRouter
    KoaApp --> TxRouter
    KoaApp --> UsersRouter

    AuthRouter --> MongooseODM
    UsedItemsRouter --> MongooseODM
    TxRouter --> MongooseODM
    UsersRouter --> MongooseODM

    MongooseODM -->|Mongoose Connection Pool| MongoDB

    AuthRouter -.->|Token Verification| FirebaseAuth
    MobileApp -.->|Uploads Item Photos| FirebaseStorage
    KoaApp -.->|Trigger Push Messages| FCM
```

### Component Roles & Responsibilities

* **Flutter Mobile App (`mobile/`)**: Cross-platform consumer application providing native experiences for used item discovery, keyword/category filtering, user trust scoring, and QR-based handover transactions.
* **Koa.js Dedicated RESTful Backend (`server/`)**: Full-featured Node.js / Koa.js application server. Exposes structured RESTful API resources (`/api/usedItems`, `/api/auth`, `/api/users`, `/api/transactions`) with centralized middleware for JWT authentication, request logging, CORS, and unified error handling.
* **MongoDB Database**: Core document database storing structured data models (Users, Used Items / Listings, Orders, OTP records, Transactions, Messages, and Audit Logs) with geospatial indexing (`2dsphere`) for location queries.
* **Supporting Services**:
  - **Firebase Cloud Storage**: Secure media hosting for user-uploaded product images.
  - **Google OAuth / Firebase Auth**: Identity verification tokens.
  - **Resend / SMTP**: Transactional email verification codes for passwordless login.

---

## 2. Core MongoDB Collections & Data Schema

Data persistence is managed via **Mongoose** schemas defining high-integrity document structures:

### `users` Collection
```json
{
  "_id": "ObjectId('64e1f...01')",
  "email": "sam@kiwishare.co.nz",
  "displayName": "Sam Yao",
  "avatarUrl": "https://...",
  "trustScore": 100,
  "isVerified": true,
  "authProvider": "google",
  "passwordHash": "$2a$12$...",
  "createdAt": "2026-08-19T00:00:00.000Z",
  "updatedAt": "2026-08-19T00:00:00.000Z"
}
```

### `items` / `usedItems` Collection
```json
{
  "_id": "ObjectId('64e1f...02')",
  "sellerId": "ObjectId('64e1f...01')",
  "title": "Retro Armchair",
  "description": "Comfortable vintage armchair in great shape.",
  "category": "Furniture",
  "condition": "good",
  "price": 4500,
  "currency": "NZD",
  "priceNzd": "45",
  "images": [
    { "url": "https://...", "thumbnailUrl": "https://...", "sortOrder": 0 }
  ],
  "location": {
    "city": "Auckland",
    "suburb": "Central",
    "coordinates": {
      "type": "Point",
      "coordinates": [174.7633, -36.8485]
    }
  },
  "isSustainable": true,
  "status": "active",
  "viewCount": 12,
  "favouriteCount": 3,
  "createdAt": "2026-08-19T00:00:00.000Z",
  "updatedAt": "2026-08-19T00:00:00.000Z"
}
```

### `orders` / `transactions` Collection
```json
{
  "_id": "ObjectId('64e1f...03')",
  "itemId": "ObjectId('64e1f...02')",
  "buyerId": "ObjectId('64e1f...04')",
  "sellerId": "ObjectId('64e1f...01')",
  "status": "completed",
  "claimCode": "QR_HANDOVER_TOKEN_ABC",
  "createdAt": "2026-08-19T00:00:00.000Z"
}
```

---

## 3. Deep Integration of Native Mobile Capabilities

To deliver a premium mobile experience that stands apart from standard responsive web browsers, KiwiShare leverages Flutter's rich native device plugins:

| Native Capability | Plugin(s) | Integration & Value-Add Use-Case |
| :--- | :--- | :--- |
| **Camera & Image Capture** | `image_picker` | Direct high-resolution photo shooting & camera roll selection for pre-loved item listings, compressed prior to edge storage. |
| **Voice Note Recording & Playback** | `record`, `just_audio` | Hardware microphone capture for voice messaging in chat threads, coupled with streaming playback and visual audio timeline. |
| **QR Code Scanner & Generator** | `mobile_scanner`, `qr_flutter` | Real-time camera barcode scanner for buyer and high-contrast dynamic QR display for seller to complete in-person handovers. |
| **GPS Location & Geocoding** | `geolocator`, `geocoding` | Precision GPS location querying and reverse-geocoding to New Zealand suburbs (e.g., Ponsonby, Newmarket, Te Aro) for distance-based sorting. |
| **Interactive Vector Mapping** | `flutter_map`, `latlong2` | Embedded OpenStreetMap tiles displaying meetup locations and item pickup zones with interactive panning and markers. |
| **Push Notifications** | `firebase_messaging` | Native APNs/FCM background device notification channels alerting users to incoming buyer messages and meetup status updates. |
| **Cloud Remote Config** | `firebase_remote_config` | Dynamic over-the-air feature flag toggling and operational configuration without requiring app store resubmissions. |

---

## 4. Atomic QR Code Handover Verification Flow

To eliminate the common second-hand marketplace hazards of **buyer ghosting**, **unverified physical exchanges**, and **seller non-delivery**, KiwiShare implements a cryptographically hashed, atomic in-person handover protocol:

```mermaid
sequenceDiagram
    autonumber
    actor Seller as Seller (Mobile App)
    actor Buyer as Buyer (Mobile App)
    participant Server as Koa Backend API (/api)
    participant Mongo as MongoDB Atlas (Cluster)

    Note over Seller,Buyer: In-Person Meetup in Aotearoa (e.g. Ponsonby Central)
    Seller->>Seller: Opens Meetup Details & displays dynamic Handover QR Code
    Buyer->>Buyer: Taps "Scan Handover QR Code" (Opens camera via mobile_scanner)
    Buyer->>Seller: Scans Seller's QR Screen
    Buyer->>Server: POST /api/transactions/handover/claim { itemId, claimCode } (JWT Auth)

    rect rgb(240, 248, 255)
        Note over Server,Mongo: Atomic Transaction Session (runMongoTransaction)
        Server->>Mongo: 1. Verify claimCode matches active QrCode token hash
        Server->>Mongo: 2. Validate item status is not already 'sold' & buyer != seller
        Server->>Mongo: 3. Atomically transfer item.ownerId = buyerId & status = 'sold'
        Server->>Mongo: 4. Increment Seller trustScore by +5 points
        Server->>Mongo: 5. Mark QrCode status = 'consumed' with scannedAt timestamp
        Server->>Mongo: 6. Transition Order status to 'completed'
        Mongo-->>Server: Commit Transaction
    end

    Server-->>Buyer: 200 OK { status: 'success', item, newOwnerId }
    Buyer->>Buyer: UI displays celebration dialog & verified ownership
    Seller->>Server: Polls order status or receives FCM push
    Seller->>Seller: Order updates to "Completed" & Trust Score +5 confirmed
```
