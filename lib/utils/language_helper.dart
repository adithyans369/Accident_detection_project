import 'package:flutter/material.dart';

class LanguageHelper {

  static Locale currentLocale = const Locale('en');

  static Map<String, Map<String, String>> translations = {

    "en": {

     "tagline":"Every second matters",
      "settings": "Settings",
      "language": "Language",
      "help_support": "Help & Support",
      "emergency_contacts": "Emergency Contacts",
      "logout": "Logout",

      "login": "Login",
      "signup": "Sign Up",
      "email": "Email",
      "password": "Password",
      "confirm_password": "Confirm Password",

      "create_account": "Create Account",
      "start_monitoring": "Register to start monitoring",
      "register": "Register",

      "forgot_password": "Forgot Password",
      "load_question": "Load Security Question",
      "verify_answer": "Verify Answer",
      "reset_password": "Reset Password",
      "new_password": "New Password",

      "enter_email": "Please enter email",
      "email_not_found": "Email not found",
      "enter_answer": "Enter answer",
      "incorrect_answer": "Incorrect answer",
      "password_mismatch": "Passwords do not match",
      "password_reset_success": "Password reset successful",
      "fill_fields": "Please fill all fields",

      "user_profile": "User Profile",
      "name": "Name",
      "age": "Age",
      "blood_group": "Blood Group",
      "mobile_number": "Mobile Number",
      "vehicle_number": "Vehicle Number",
      "address": "Address",
      "emergency_contact1": "Emergency Contact 1",
      "emergency_contact2": "Emergency Contact 2",
      "allergies": "Allergies",
      "profile_updated": "Profile Updated",

      "driver": "Driver",
      "vehicle": "Vehicle",
      "monitoring_status": "Monitoring Status",
      "emergency_numbers": "Emergency Numbers",

      "ambulance": "Ambulance",
      "police": "Police",
      "fire_force": "Fire Force",

      "accident_alert": "Accident Alert",
      "accident_detected": "ACCIDENT DETECTED",
      "send_alert": "Send Alert",
      "cancel": "Cancel",
      "alert_sent": "Alert sent",
      "sending_in": "Sending alert in",
      "seconds": "seconds",
      "sending_alert": "Sending alert to emergency contacts",

      "location": "Location",
      "time": "Time",
      "unknown_driver": "Unknown Driver",
      "location_unknown": "Location Unknown",
      "not_set": "Not Set",

      /// SECURITY QUESTIONS
      "color_question": "What is your favourite color?",
      "pet_question": "What is your pet's name?",
      "city_question": "What city were you born in?",

    },

    "ml": {

      "tagline": "ഓരോ സെക്കന്റും വിലപ്പെട്ടതാണ്",
      "settings": "ക്രമീകരണങ്ങൾ",
      "language": "ഭാഷ",
      "help_support": "സഹായവും പിന്തുണയും",
      "emergency_contacts": "അപകട ബന്ധങ്ങൾ",
      "logout": "ലോഗ് ഔട്ട്",

      "login": "ലോഗിൻ",
      "signup": "സൈൻ അപ്",
      "email": "ഇമെയിൽ",
      "password": "പാസ്‌വേഡ്",
      "confirm_password": "പാസ്‌വേഡ് സ്ഥിരീകരിക്കുക",

      "create_account": "അക്കൗണ്ട് സൃഷ്ടിക്കുക",
      "start_monitoring": "മോണിറ്ററിംഗ് ആരംഭിക്കാൻ രജിസ്റ്റർ ചെയ്യുക",
      "register": "രജിസ്റ്റർ",

      "forgot_password": "പാസ്‌വേഡ് മറന്നോ",
      "load_question": "സുരക്ഷാ ചോദ്യം ലോഡ് ചെയ്യുക",
      "verify_answer": "ഉത്തരം പരിശോധിക്കുക",
      "reset_password": "പാസ്‌വേഡ് റീസെറ്റ് ചെയ്യുക",
      "new_password": "പുതിയ പാസ്‌വേഡ്",

      "enter_email": "ഇമെയിൽ നൽകുക",
      "email_not_found": "ഇമെയിൽ കണ്ടെത്തിയില്ല",
      "enter_answer": "ഉത്തരം നൽകുക",
      "incorrect_answer": "ഉത്തരം തെറ്റാണ്",
      "password_mismatch": "പാസ്‌വേഡുകൾ പൊരുത്തപ്പെടുന്നില്ല",
      "password_reset_success": "പാസ്‌വേഡ് വിജയകരമായി മാറ്റി",
      "fill_fields": "എല്ലാ ഫീൽഡുകളും പൂരിപ്പിക്കുക",

      "user_profile": "ഉപയോക്തൃ പ്രൊഫൈൽ",
      "name": "പേര്",
      "age": "പ്രായം",
      "blood_group": "രക്തഗ്രൂപ്പ്",
      "mobile_number": "മൊബൈൽ നമ്പർ",
      "vehicle_number": "വാഹന നമ്പർ",
      "address": "വിലാസം",
      "emergency_contact1": "അപകട ബന്ധം 1",
      "emergency_contact2": "അപകട ബന്ധം 2",
      "allergies": "അലർജികൾ",
      "profile_updated": "പ്രൊഫൈൽ അപ്‌ഡേറ്റ് ചെയ്തു",

      "driver": "ഡ്രൈവർ",
      "vehicle": "വാഹനം",
      "monitoring_status": "മോണിറ്ററിംഗ് നില",
      "emergency_numbers": "അടിയന്തര നമ്പറുകൾ",

      "ambulance": "ആംബുലൻസ്",
      "police": "പോലീസ്",
      "fire_force": "ഫയർ ഫോഴ്‌സ്",

      "accident_alert": "അപകട അലർട്ട്",
      "accident_detected": "അപകടം കണ്ടെത്തി",
      "send_alert": "അലർട്ട് അയയ്ക്കുക",
      "cancel": "റദ്ദാക്കുക",
      "alert_sent": "അലർട്ട് അയച്ചു",
      "sending_in": "അലർട്ട് അയക്കുന്നു",
      "seconds": "സെക്കൻഡ്",
      "sending_alert": "അപകട വിവരം അയക്കുന്നു",

      "location": "ലൊക്കേഷൻ",
      "time": "സമയം",
      "unknown_driver": "അറിയാത്ത ഡ്രൈവർ",
      "location_unknown": "ലൊക്കേഷൻ ലഭ്യമല്ല",
      "not_set": "സജ്ജമാക്കിയിട്ടില്ല",

      /// SECURITY QUESTIONS
      "color_question": "നിങ്ങളുടെ പ്രിയപ്പെട്ട നിറം എന്താണ്?",
      "pet_question": "നിങ്ങളുടെ വളർത്തുമൃഗത്തിന്റെ പേര് എന്താണ്?",
      "city_question": "നിങ്ങൾ ജനിച്ച നഗരം ഏത്?",

    }

  };

  static String t(String key) {

    String lang = currentLocale.languageCode;

    if (translations[lang] != null &&
        translations[lang]![key] != null) {
      return translations[lang]![key]!;
    }

    return key;
  }

  static void setLocale(Locale locale) {
    currentLocale = locale;
  }

}