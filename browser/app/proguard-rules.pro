# The page talks to the app through this bridge by name.
-keepclassmembers class com.langualens.browser.Bridge {
   public *;
}
-keepattributes JavascriptInterface
