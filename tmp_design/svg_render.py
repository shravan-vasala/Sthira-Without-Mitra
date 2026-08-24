def write_svgs():
    import os

    # Shared parameters for Sthira Chibi
    palette = {
        'ivory': '#F5F0E6',
        'taupe': '#D3C8C2',
        'plum': '#322432',
        'peachEar': '#F7DACF',
        'peachCheek': '#FDBAB0',
        'champagne': '#FFFDF8',
        'bg': '#2B1D2B'
    }

    # Helper for generating SVG template
    def build_svg(palette, show_bg=True, monochrome=False):
        fill_ivory = '#555555' if monochrome else palette['ivory']
        fill_taupe = '#333333' if monochrome else palette['taupe']
        fill_plum = '#111111' if monochrome else palette['plum']
        fill_peachEar = '#444444' if monochrome else palette['peachEar']
        fill_peachCheek = '#444444' if monochrome else palette['peachCheek']
        fill_champagne = '#EEEEEE' if monochrome else palette['champagne']

        bg_rect = f'<rect width="160" height="160" fill="{palette["bg"]}"/>' if show_bg else ''

        return f'''<svg width="160" height="160" viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
    {bg_rect}
    <g transform="translate(0, 0)">
        <!-- Back Right Leg -->
        <g transform="translate(85, 120)">
            <rect x="-12" y="-10" width="24" height="30" rx="12" fill="{fill_taupe}" />
        </g>
        
        <!-- Front Right Leg -->
        <g transform="translate(55, 122)">
            <rect x="-12" y="-10" width="24" height="28" rx="12" fill="{fill_taupe}" />
        </g>

        <!-- Tail -->
        <g transform="translate(110, 95)">
            <path d="M 0 0 Q 10 8 12 20 Q 6 10 0 0" fill="{fill_ivory}" />
            <circle cx="12" cy="21" r="4" fill="{fill_taupe}" />
        </g>

        <!-- Body -->
        <g transform="translate(82, 95)">
            <rect x="-37.5" y="-30" width="75" height="60" rx="30" fill="{fill_ivory}" />
            <!-- Soft belly shadow -->
            <ellipse cx="0" cy="18" rx="30" ry="10" fill="{fill_taupe}" opacity="0.8" />
        </g>

        <!-- Back Left Leg -->
        <g transform="translate(95, 125)">
            <rect x="-14" y="-10" width="28" height="32" rx="14" fill="{fill_ivory}" />
            <!-- Toes -->
            <path d="M -12 15 A 4 4 0 0 1 -4 15 Z" fill="{fill_taupe}" />
            <path d="M -3 15 A 4 4 0 0 1 5 15 Z" fill="{fill_taupe}" />
        </g>

        <!-- Front Left Leg -->
        <g transform="translate(60, 128)">
            <rect x="-14" y="-10" width="28" height="30" rx="14" fill="{fill_ivory}" />
            <!-- Toes -->
            <path d="M -12 13 A 4 4 0 0 1 -4 13 Z" fill="{fill_taupe}" />
            <path d="M -3 13 A 4 4 0 0 1 5 13 Z" fill="{fill_taupe}" />
        </g>

        <!-- HEAD GROUP -->
        <g transform="translate(65, 75)">
            <!-- Far Ear (Right Ear) -->
            <g transform="translate(-5, -20)">
                <ellipse cx="40" cy="15" rx="15" ry="22.5" fill="{fill_taupe}" />
            </g>

            <!-- Main Head Sphere -->
            <ellipse cx="0" cy="-25" rx="42" ry="40" fill="{fill_ivory}" />
            
            <!-- Head Highlight -->
            <ellipse cx="-5" cy="-53" rx="25" ry="9" fill="{fill_champagne}" opacity="0.9" />

            <!-- Cheek blush -->
            <ellipse cx="-18" cy="-10" rx="8" ry="5" fill="{fill_peachCheek}" />

            <!-- Left Eye -->
            <ellipse cx="-20" cy="-25" rx="5" ry="7" fill="{fill_plum}" />
            <circle cx="-21.5" cy="-27.5" r="1.5" fill="{fill_champagne}" />

            <!-- Right Eye -->
            <ellipse cx="-4" cy="-25" rx="4" ry="6" fill="{fill_plum}" />
            <circle cx="-4.5" cy="-27.5" r="1.2" fill="{fill_champagne}" />

            <!-- Trunk -->
            <g transform="translate(-30, -5)">
                <path d="M 0 -15 Q -25 10 -15 30 Q -5 35 5 15 Q 0 0 20 -10 Q 0 -15 0 -15 Z" fill="{fill_ivory}" />
                <!-- Fold shading lines -->
                <!-- Translating lines from flutter to stroke SVG -->
                <line x1="-13" y1="8" x2="-7" y2="10" stroke="{fill_taupe}" stroke-width="2" stroke-linecap="round" />
                <line x1="-11" y1="15" x2="-5" y2="17" stroke="{fill_taupe}" stroke-width="2" stroke-linecap="round" />
            </g>

            <!-- Near Ear (Left Ear) -->
            <g transform="translate(15, -25)">
                <!-- Outer Ear -->
                <path d="M 0 -15 C -20 -20, -40 20, -15 45 C 10 65, 40 30, 25 0 Z" fill="{fill_ivory}" />
                <!-- Inner Ear (Peach) -->
                <path d="M 5 -5 C -10 -5, -25 20, -5 38 C 10 48, 28 25, 18 5 Z" fill="{fill_peachEar}" />
                <path d="M 4 5 A 17.5 30 0 0 0 4 65" fill="{fill_taupe}" stroke="{fill_taupe}" stroke-width="2" opacity="0.6" />
            </g>
        </g>
    </g>
</svg>'''

    base_dir = r"C:\Users\sande\.gemini\antigravity\brain\7d414627-571d-4c75-b3fe-ca0febe97a5b"
    os.makedirs(base_dir, exist_ok=True)

    # Write SVGs
    with open(os.path.join(base_dir, 'mitra_idle_160_bg.svg'), 'w') as f:
        f.write(build_svg(palette, show_bg=True, monochrome=False))

    with open(os.path.join(base_dir, 'mitra_idle_160_monochrome.svg'), 'w') as f:
        f.write(build_svg(palette, show_bg=True, monochrome=True))

    with open(os.path.join(base_dir, 'mitra_idle_160_no_bg.svg'), 'w') as f:
        f.write(build_svg(palette, show_bg=False, monochrome=False))

    # To show 48px, 80px, 100px, 160px we can use the same SVG but styled via Markdown!
    print("SVGs generated successfully.")

if __name__ == '__main__':
    write_svgs()
