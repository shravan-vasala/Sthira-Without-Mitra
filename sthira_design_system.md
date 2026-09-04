# Sthira Design System Reference

Here is your beautifully structured **Sthira Design System** cheat sheet, updated to perfectly reflect the dark, grounded, and premium "Steady Aura" aesthetic that we love and are sticking with!

<br>

<div style="background: #181818; padding: 40px; border-radius: 24px; color: white; font-family: 'General Sans', system-ui, -apple-system, sans-serif; max-width: 700px; box-shadow: 0 20px 40px rgba(0,0,0,0.4);">
  
  <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 32px;">
    <div>
      <h2 style="margin: 0; font-family: 'Cabinet Grotesk', sans-serif; font-size: 32px; font-weight: 800; color: #E29B65; letter-spacing: -1px;">Sthira</h2>
      <div style="color: #7FA35C; font-weight: 500; font-size: 16px; margin-top: 4px;">steady, every day</div>
    </div>
    <div style="text-align: right;">
      <div style="font-size: 12px; color: rgba(255,255,255,0.4); text-transform: uppercase; letter-spacing: 2px;">Design System</div>
    </div>
  </div>

  <!-- Typography -->
  <div style="display: flex; gap: 16px; margin-bottom: 32px;">
    <div style="background: #171F1B; padding: 24px; border-radius: 16px; flex: 1; border: 1px solid rgba(255,255,255,0.05);">
      <div style="font-size: 13px; color: #B5A5AA; margin-bottom: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;">Headline</div>
      <div style="font-family: 'Cabinet Grotesk', sans-serif; font-size: 32px; font-weight: 800; color: #E29B65; letter-spacing: -0.5px; line-height: 1.1;">Cabinet<br>Grotesk</div>
    </div>
    <div style="background: #171F1B; padding: 24px; border-radius: 16px; flex: 1; border: 1px solid rgba(255,255,255,0.05);">
      <div style="font-size: 13px; color: #B5A5AA; margin-bottom: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;">Body</div>
      <div style="font-family: 'General Sans', sans-serif; font-size: 32px; font-weight: 400; color: #EFE8EA; line-height: 1.1;">General<br>Sans</div>
    </div>
  </div>

  <!-- Colors -->
  <div style="display: flex; flex-direction: column; gap: 12px;">
    
    <div style="background: #0F1513; padding: 20px 24px; border-radius: 16px; display: flex; justify-content: space-between; align-items: center; border: 1px solid rgba(255,255,255,0.1);">
      <span style="font-weight: 700; font-size: 18px; color: white;">Deep Forest Black <span style="font-weight: 400; font-size: 14px; opacity: 0.6; margin-left: 8px;">Scaffold Background</span></span>
      <span style="font-family: monospace; font-size: 16px; color: white; opacity: 0.8;">#0F1513</span>
    </div>
    
    <div style="background: #171F1B; padding: 20px 24px; border-radius: 16px; display: flex; justify-content: space-between; align-items: center; border: 1px solid rgba(255,255,255,0.05);">
      <span style="font-weight: 700; font-size: 18px; color: white;">Dark Surface <span style="font-weight: 400; font-size: 14px; opacity: 0.6; margin-left: 8px;">Cards & Bottom Sheets</span></span>
      <span style="font-family: monospace; font-size: 16px; color: white; opacity: 0.8;">#171F1B</span>
    </div>
    
    <div style="background: #E29B65; padding: 20px 24px; border-radius: 16px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(0,0,0,0.2);">
      <span style="font-weight: 700; font-size: 18px; color: #2D1A25;">Sandy Peach <span style="font-weight: 500; font-size: 14px; opacity: 0.7; margin-left: 8px;">Primary Accent & Buttons</span></span>
      <span style="font-family: monospace; font-size: 16px; color: #2D1A25; opacity: 0.9;">#E29B65</span>
    </div>
    
    <div style="background: #EFE8EA; padding: 20px 24px; border-radius: 16px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(0,0,0,0.2);">
      <span style="font-weight: 700; font-size: 18px; color: #2D1A25;">Off-White <span style="font-weight: 500; font-size: 14px; opacity: 0.7; margin-left: 8px;">Primary Text</span></span>
      <span style="font-family: monospace; font-size: 16px; color: #2D1A25; opacity: 0.9;">#EFE8EA</span>
    </div>
    
    <div style="background: #B5A5AA; padding: 20px 24px; border-radius: 16px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(0,0,0,0.2);">
      <span style="font-weight: 700; font-size: 18px; color: #2D1A25;">Muted Sage/Sand <span style="font-weight: 500; font-size: 14px; opacity: 0.7; margin-left: 8px;">Secondary Text</span></span>
      <span style="font-family: monospace; font-size: 16px; color: #2D1A25; opacity: 0.9;">#B5A5AA</span>
    </div>
    
  </div>
</div>

## DESIGN CONTEXT: "Sasirekha Minimalist Tile Style"

When building or refactoring lists, menus, or repeating items, strictly adhere to the "Sasirekha Minimalist Tile Style":
1. **Completely Flat & Borderless:** Do NOT wrap list items in Card widgets or explicit container borders. Items must have a transparent background (`Colors.transparent`) to sit entirely flush against the app's `scaffoldBg`.
2. **Negative Space over Lines:** Never use `Divider` lines or distinct card margins. Separate items purely using consistent vertical spacing/padding (e.g., `Padding(padding: EdgeInsets.only(bottom: kSpace2))`).
3. **Leading Elements:** The far-left element should be a simple, slightly rounded icon container or image that anchors the row.
4. **Typography Contrast:** Use strong, bold titles (`context.text.bodyBold` or `title`) paired with highly muted subtitles (`context.text.caption` colored with `context.colors.textMedium` or `textLight`).
5. **Trailing Actions:** The far-right element should be minimal, utilizing simple `IconButton`s (like a vertical 3-dot menu or a simple thin-outline icon) without heavy button backgrounds.
6. **Goal:** The interface should feel infinitely open, lightweight, and modern, using alignment and space rather than boxes and borders to group information.
