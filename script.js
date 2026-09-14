const FALLBACK_VERSION = "1.2.10";
const RELEASES_API = "https://api.github.com/repos/jeevan-vj/windowsnap/releases/latest";

const menuToggle = document.querySelector(".menu-toggle");
const mobileMenu = document.getElementById("mobile-menu");
const moreToggle = document.querySelector(".more-toggle");
const moreOptions = document.getElementById("mac-options");

function setExpanded(button, expanded) {
    button.setAttribute("aria-expanded", String(expanded));
}

menuToggle?.addEventListener("click", () => {
    const open = menuToggle.getAttribute("aria-expanded") !== "true";
    setExpanded(menuToggle, open);
    menuToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    mobileMenu.hidden = !open;
});

mobileMenu?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
        setExpanded(menuToggle, false);
        menuToggle.setAttribute("aria-label", "Open menu");
        mobileMenu.hidden = true;
    });
});

moreToggle?.addEventListener("click", () => {
    const open = moreToggle.getAttribute("aria-expanded") !== "true";
    setExpanded(moreToggle, open);
    moreOptions.hidden = !open;
});

document.querySelectorAll(".copy-cmd").forEach((button) => {
    button.addEventListener("click", async () => {
        const value = button.dataset.copy ?? button.querySelector("code")?.textContent ?? "";
        try {
            await navigator.clipboard.writeText(value.replace(/^\$\s*/, ""));
            button.classList.add("copied");
            window.setTimeout(() => button.classList.remove("copied"), 1200);
        } catch {
            /* ignore clipboard failures */
        }
    });
});

function assetUrl(assets, suffix) {
    return assets.find((asset) => asset.name.endsWith(suffix))?.browser_download_url;
}

async function hydrateLatestRelease() {
    const line = document.getElementById("releaseLine");
    try {
        const response = await fetch(RELEASES_API);
        if (!response.ok) {
            return;
        }
        const release = await response.json();
        const version = String(release.tag_name ?? FALLBACK_VERSION).replace(/^v/, "");
        const assets = Array.isArray(release.assets) ? release.assets : [];
        const dmg = assetUrl(assets, ".dmg");
        const zip = assetUrl(assets, ".zip");
        const dmgLink = document.getElementById("dmgLink");
        const dmgOption = document.getElementById("dmgOption");
        const zipOption = document.getElementById("zipOption");
        if (dmg && dmgLink && dmgOption) {
            dmgLink.href = dmg;
            dmgOption.href = dmg;
        }
        if (zip && zipOption) {
            zipOption.href = zip;
        }
        if (line) {
            line.textContent = `Latest release: v${version}`;
        }
    } catch {
        if (line) {
            line.textContent = `Latest release: v${FALLBACK_VERSION}`;
        }
    }
}

hydrateLatestRelease();
