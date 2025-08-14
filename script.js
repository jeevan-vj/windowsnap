// WindowSnap Website JavaScript - Future 2030 Interactive Experience

class WindowSnapWebsite {
    constructor() {
        this.init();
    }

    init() {
        this.setupLoadingScreen();
        this.setupNavigation();
        this.setupScrollEffects();
        this.setupRevealAnimations();
        this.setupDemoInteractions();
        this.setupParticles();
        this.setupKeyboardShortcuts();
        this.setupSmoothScrolling();
    }

    // Loading Screen with Progress Animation
    setupLoadingScreen() {
        const loadingScreen = document.getElementById('loadingScreen');
        const progressBar = document.querySelector('.loading-progress');
        
        let progress = 0;
        const interval = setInterval(() => {
            progress += Math.random() * 15;
            if (progress >= 100) {
                progress = 100;
                clearInterval(interval);
                setTimeout(() => {
                    loadingScreen.classList.add('hidden');
                }, 500);
            }
            progressBar.style.width = `${progress}%`;
        }, 100);

        // Hide loading screen after DOM is loaded
        window.addEventListener('load', () => {
            setTimeout(() => {
                if (progress < 100) {
                    progress = 100;
                    progressBar.style.width = '100%';
                    setTimeout(() => {
                        loadingScreen.classList.add('hidden');
                    }, 500);
                }
            }, 1000);
        });
    }

    // Advanced Navigation with Scroll Effects
    setupNavigation() {
        const navbar = document.getElementById('navbar');
        const navToggle = document.getElementById('navToggle');
        const navMenu = document.querySelector('.nav-menu');
        
        // Scroll effect for navbar
        let lastScrollY = window.scrollY;
        window.addEventListener('scroll', () => {
            const currentScrollY = window.scrollY;
            
            if (currentScrollY > 100) {
                navbar.classList.add('scrolled');
            } else {
                navbar.classList.remove('scrolled');
            }

            // Hide/show navbar on scroll
            if (currentScrollY > lastScrollY && currentScrollY > 200) {
                navbar.style.transform = 'translateY(-100%)';
            } else {
                navbar.style.transform = 'translateY(0)';
            }
            
            lastScrollY = currentScrollY;
        });

        // Mobile menu toggle
        navToggle.addEventListener('click', () => {
            navMenu.classList.toggle('active');
            navToggle.classList.toggle('active');
        });

        // Close mobile menu when clicking links
        document.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', () => {
                navMenu.classList.remove('active');
                navToggle.classList.remove('active');
            });
        });
    }

    // Scroll-triggered Animations
    setupScrollEffects() {
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.animationPlayState = 'running';
                }
            });
        }, observerOptions);

        // Observe animated elements
        document.querySelectorAll('[data-reveal]').forEach(el => {
            observer.observe(el);
        });
    }

    // Reveal Animations on Scroll
    setupRevealAnimations() {
        const revealElements = document.querySelectorAll('[data-reveal]');
        
        const revealObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('revealed');
                }
            });
        }, {
            threshold: 0.15,
            rootMargin: '0px 0px -100px 0px'
        });

        revealElements.forEach(el => {
            revealObserver.observe(el);
        });
    }

    // Interactive Demo Section
    setupDemoInteractions() {
        const demoButtons = document.querySelectorAll('.demo-btn');
        const leftWindow = document.getElementById('demoWindowLeft');
        const rightWindow = document.getElementById('demoWindowRight');

        const positions = {
            left: {
                left: { width: '48%', height: '80%', top: '10%', left: '2%' },
                right: { width: '48%', height: '80%', top: '10%', right: '2%' }
            },
            right: {
                left: { width: '48%', height: '80%', top: '10%', right: '52%' },
                right: { width: '48%', height: '80%', top: '10%', right: '2%' }
            },
            maximize: {
                left: { width: '96%', height: '90%', top: '5%', left: '2%' },
                right: { width: '0%', height: '0%', top: '50%', right: '50%' }
            },
            quarter: {
                left: { width: '48%', height: '40%', top: '10%', left: '2%' },
                right: { width: '48%', height: '40%', top: '50%', right: '2%' }
            }
        };

        demoButtons.forEach(button => {
            button.addEventListener('click', () => {
                const position = button.dataset.position;
                
                // Remove active class from all buttons
                demoButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');

                // Apply positions
                if (positions[position]) {
                    Object.assign(leftWindow.style, positions[position].left);
                    Object.assign(rightWindow.style, positions[position].right);
                }
            });
        });

        // Auto-cycle demo every 4 seconds
        let currentDemo = 0;
        const demoPositions = ['left', 'right', 'maximize', 'quarter'];
        
        setInterval(() => {
            currentDemo = (currentDemo + 1) % demoPositions.length;
            const activeButton = document.querySelector(`[data-position="${demoPositions[currentDemo]}"]`);
            if (activeButton) {
                activeButton.click();
            }
        }, 4000);
    }

    // Dynamic Particle System
    setupParticles() {
        const particleContainer = document.querySelector('.hero-particles');
        const particleCount = 20;

        for (let i = 0; i < particleCount; i++) {
            const particle = document.createElement('div');
            particle.className = 'particle';
            particle.style.cssText = `
                position: absolute;
                width: ${Math.random() * 4 + 1}px;
                height: ${Math.random() * 4 + 1}px;
                background: linear-gradient(45deg, #6366f1, #8b5cf6);
                border-radius: 50%;
                top: ${Math.random() * 100}%;
                left: ${Math.random() * 100}%;
                animation: particleFloat ${Math.random() * 10 + 5}s ease-in-out infinite;
                animation-delay: ${Math.random() * 5}s;
                opacity: ${Math.random() * 0.5 + 0.3};
            `;
            particleContainer.appendChild(particle);
        }

        // Add particle animation CSS
        const style = document.createElement('style');
        style.textContent = `
            @keyframes particleFloat {
                0%, 100% { transform: translateY(0) rotate(0deg); }
                25% { transform: translateY(-20px) rotate(90deg); }
                50% { transform: translateY(-10px) rotate(180deg); }
                75% { transform: translateY(-30px) rotate(270deg); }
            }
        `;
        document.head.appendChild(style);
    }

    // Keyboard Shortcuts for Demo
    setupKeyboardShortcuts() {
        const shortcuts = {
            'KeyL': 'left',
            'KeyR': 'right',
            'KeyM': 'maximize',
            'KeyQ': 'quarter'
        };

        document.addEventListener('keydown', (e) => {
            if (shortcuts[e.code]) {
                e.preventDefault();
                const button = document.querySelector(`[data-position="${shortcuts[e.code]}"]`);
                if (button) {
                    button.click();
                    this.showKeyboardFeedback(e.code);
                }
            }
        });
    }

    // Show keyboard feedback
    showKeyboardFeedback(keyCode) {
        const feedback = document.createElement('div');
        feedback.textContent = `Key pressed: ${keyCode.replace('Key', '')}`;
        feedback.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(99, 102, 241, 0.9);
            color: white;
            padding: 10px 20px;
            border-radius: 8px;
            font-weight: 600;
            z-index: 10000;
            pointer-events: none;
            animation: feedbackFade 1s ease forwards;
        `;

        document.body.appendChild(feedback);

        // Add feedback animation
        const style = document.createElement('style');
        style.textContent = `
            @keyframes feedbackFade {
                0% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
                100% { opacity: 0; transform: translate(-50%, -50%) scale(0.8); }
            }
        `;
        document.head.appendChild(style);

        setTimeout(() => {
            document.body.removeChild(feedback);
        }, 1000);
    }

    // Smooth Scrolling Enhancement
    setupSmoothScrolling() {
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const targetId = this.getAttribute('href');
                const targetElement = document.querySelector(targetId);
                
                if (targetElement) {
                    const offsetTop = targetElement.offsetTop - 80; // Account for navbar
                    
                    window.scrollTo({
                        top: offsetTop,
                        behavior: 'smooth'
                    });
                }
            });
        });
    }

    // Advanced Feature Card Interactions
    setupFeatureCards() {
        const featureCards = document.querySelectorAll('.feature-card');
        
        featureCards.forEach(card => {
            card.addEventListener('mouseenter', () => {
                card.style.transform = 'translateY(-10px) rotateX(5deg)';
                card.style.boxShadow = '0 20px 40px rgba(99, 102, 241, 0.3)';
            });

            card.addEventListener('mouseleave', () => {
                card.style.transform = 'translateY(0) rotateX(0deg)';
                card.style.boxShadow = '';
            });
        });
    }

    // Window Snap Simulation
    simulateWindowSnap() {
        const windows = document.querySelectorAll('.demo-window');
        
        windows.forEach((window, index) => {
            setTimeout(() => {
                window.style.transition = 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
                window.style.transform = 'scale(1.05)';
                
                setTimeout(() => {
                    window.style.transform = 'scale(1)';
                }, 200);
            }, index * 200);
        });
    }

    // Performance Optimization
    throttle(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // Accessibility Enhancements
    setupAccessibility() {
        // Add focus indicators
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                document.body.classList.add('keyboard-navigation');
            }
        });

        document.addEventListener('mousedown', () => {
            document.body.classList.remove('keyboard-navigation');
        });

        // Announce page changes for screen readers
        const announcePageChange = (message) => {
            const announcement = document.createElement('div');
            announcement.setAttribute('aria-live', 'polite');
            announcement.setAttribute('aria-atomic', 'true');
            announcement.style.position = 'absolute';
            announcement.style.left = '-10000px';
            announcement.textContent = message;
            document.body.appendChild(announcement);
            
            setTimeout(() => {
                document.body.removeChild(announcement);
            }, 1000);
        };
    }

    // Theme Switching (for future implementation)
    setupThemeSwitch() {
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');
        
        prefersDark.addEventListener('change', (e) => {
            if (e.matches) {
                document.body.classList.add('dark-theme');
            } else {
                document.body.classList.remove('dark-theme');
            }
        });
    }

    // Analytics and Tracking (placeholder for future implementation)
    trackInteractions() {
        const trackableElements = document.querySelectorAll('[data-track]');
        
        trackableElements.forEach(element => {
            element.addEventListener('click', (e) => {
                const trackingData = e.target.dataset.track;
                console.log('Tracking:', trackingData);
                // Future: Send to analytics service
            });
        });
    }
}

// Advanced Intersection Observer for complex animations
class AdvancedAnimations {
    constructor() {
        this.setupComplexAnimations();
    }

    setupComplexAnimations() {
        this.setupStaggeredAnimations();
        this.setupParallaxEffects();
        this.setupMorphingEffects();
    }

    setupStaggeredAnimations() {
        const staggeredElements = document.querySelectorAll('.features-grid .feature-card');
        
        const staggerObserver = new IntersectionObserver((entries) => {
            entries.forEach((entry, index) => {
                if (entry.isIntersecting) {
                    setTimeout(() => {
                        entry.target.style.transform = 'translateY(0)';
                        entry.target.style.opacity = '1';
                    }, index * 100);
                }
            });
        }, { threshold: 0.1 });

        staggeredElements.forEach((el, index) => {
            el.style.transform = 'translateY(50px)';
            el.style.opacity = '0';
            el.style.transition = `all 0.6s ease ${index * 0.1}s`;
            staggerObserver.observe(el);
        });
    }

    setupParallaxEffects() {
        const parallaxElements = document.querySelectorAll('.hero-background');
        
        window.addEventListener('scroll', this.throttle(() => {
            const scrolled = window.pageYOffset;
            const rate = scrolled * -0.3;
            
            parallaxElements.forEach(element => {
                element.style.transform = `translateY(${rate}px)`;
            });
        }, 10));
    }

    setupMorphingEffects() {
        const morphElements = document.querySelectorAll('.feature-icon');
        
        morphElements.forEach(element => {
            element.addEventListener('mouseenter', () => {
                element.style.transform = 'scale(1.2) rotate(10deg)';
                element.style.filter = 'hue-rotate(45deg)';
            });

            element.addEventListener('mouseleave', () => {
                element.style.transform = 'scale(1) rotate(0deg)';
                element.style.filter = 'hue-rotate(0deg)';
            });
        });
    }

    throttle(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new WindowSnapWebsite();
    new AdvancedAnimations();
});

// Performance monitoring
window.addEventListener('load', () => {
    const loadTime = performance.now();
    console.log(`🚀 WindowSnap website loaded in ${loadTime.toFixed(2)}ms`);
});

// Export for module usage (if needed)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { WindowSnapWebsite, AdvancedAnimations };
}
