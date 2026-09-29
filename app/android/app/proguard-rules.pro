# Release builds are shrunk by R8. Room creates its databases by reflection (FooDatabase_Impl), so R8
# thinks those classes are unused and strips them. WorkManager (pulled in by the Google Mobile Ads SDK)
# then crashes the app on launch with "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
