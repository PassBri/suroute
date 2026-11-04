package com.rutaalacima.app.ui.finanzas

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.vector.ImageVector

/** Íconos de Material que la persona puede elegir para un hito (mismas claves y orden que la web, web/js/56-hitos.js). */
val ICONOS_HITO: List<Pair<String, ImageVector>> = listOf(
    "home" to Icons.Filled.Home,
    "apartment" to Icons.Filled.Apartment,
    "cottage" to Icons.Filled.Cottage,
    "flight" to Icons.Filled.Flight,
    "beach_access" to Icons.Filled.BeachAccess,
    "sailing" to Icons.Filled.Sailing,
    "directions_car" to Icons.Filled.DirectionsCar,
    "two_wheeler" to Icons.Filled.TwoWheeler,
    "directions_bike" to Icons.Filled.DirectionsBike,
    "school" to Icons.Filled.School,
    "menu_book" to Icons.Filled.MenuBook,
    "lightbulb" to Icons.Filled.Lightbulb,
    "credit_card" to Icons.Filled.CreditCard,
    "account_balance" to Icons.Filled.AccountBalance,
    "payments" to Icons.Filled.Payments,
    "savings" to Icons.Filled.Savings,
    "trending_up" to Icons.Filled.TrendingUp,
    "diamond" to Icons.Filled.Diamond,
    "storefront" to Icons.Filled.Storefront,
    "business_center" to Icons.Filled.BusinessCenter,
    "work" to Icons.Filled.Work,
    "laptop" to Icons.Filled.Laptop,
    "smartphone" to Icons.Filled.Smartphone,
    "rocket_launch" to Icons.Filled.RocketLaunch,
    "people" to Icons.Filled.People,
    "favorite" to Icons.Filled.Favorite,
    "child_friendly" to Icons.Filled.ChildFriendly,
    "pets" to Icons.Filled.Pets,
    "cake" to Icons.Filled.Cake,
    "celebration" to Icons.Filled.Celebration,
    "emoji_events" to Icons.Filled.EmojiEvents,
    "workspace_premium" to Icons.Filled.WorkspacePremium,
    "star" to Icons.Filled.Star,
    "flag" to Icons.Filled.Flag,
    "hiking" to Icons.Filled.Hiking,
    "terrain" to Icons.Filled.Terrain,
    "landscape" to Icons.Filled.Landscape,
    "park" to Icons.Filled.Park,
    "fitness_center" to Icons.Filled.FitnessCenter,
    "sports_soccer" to Icons.Filled.SportsSoccer,
    "music_note" to Icons.Filled.MusicNote,
    "palette" to Icons.Filled.Palette,
    "camera_alt" to Icons.Filled.CameraAlt,
    "restaurant" to Icons.Filled.Restaurant,
    "local_hospital" to Icons.Filled.LocalHospital,
    "spa" to Icons.Filled.Spa,
    "volunteer_activism" to Icons.Filled.VolunteerActivism,
    "church" to Icons.Filled.Church
)

fun iconoHitoClave(k: String?): ImageVector? = k?.let { c -> ICONOS_HITO.firstOrNull { it.first == c }?.second }
