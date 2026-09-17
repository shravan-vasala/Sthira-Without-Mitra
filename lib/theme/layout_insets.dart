import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// Clearance for the floating pill bottom nav in [ScaffoldWithNavBar].
///
/// Body uses [extendBody], so scrollables must leave this much room at the
/// bottom or the last content sits under the nav and cannot be reached.
const double kFloatingNavClearance = 100;

/// Extra space below page content inside tab shells (nav + breathing room).
const double kShellScrollBottomPadding = kFloatingNavClearance + 16;

/// Horizontal inset for main-shell screens (Home / Progress / Profile).
const double kScreenPadding = Spacing.screen;

/// Default surface card corner radius.
const double kCardRadius = Radii.card;

/// Modal bottom sheet top corner radius (matches [BottomSheetTheme]).
const double kSheetRadius = Radii.sheet;

/// Primary / elevated button corner radius.
const double kButtonRadius = Radii.control;

/// Outlined button corner radius.
const double kOutlinedButtonRadius = Radii.control;

/// Full-width primary save CTA height.
const double kPrimaryButtonHeight = 52;

/// Compact row action height (Photo / Describe / Adjust).
const double kCompactButtonHeight = 40;

