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
        this.setupMouseEffects();
        this.setupAdvancedAnimations();
        this.setupMobileOptimizations();
        this.setupFloatingElements();
        this.setupCharacterAnimations();
    }

    // Mobile-specific optimizations
    setupMobileOptimizations() {
        // Handle orientation change
        window.addEventListener('orientationchange', () => {
            setTimeout(() => {
                this.setupParticles(); // Recreate particles for new dimensions
                this.handleResize();
            }, 100);
        });

        // Handle resize
        window.addEventListener('resize', this.throttle(() => {
            this.handleResize();
        }, 250));

        // Optimize scroll performance on mobile
        if ('ontouchstart' in window) {
            let ticking = false;
            
            const optimizedScroll = () => {
                if (!ticking) {
                    requestAnimationFrame(() => {
                        // Mobile-optimized scroll effects
                        this.updateScrollEffects();
                        ticking = false;
                    });
                    ticking = true;
                }
            };

            window.addEventListener('scroll', optimizedScroll, { passive: true });
        }

        // Prevent zoom on double tap
        let lastTouchEnd = 0;
        document.addEventListener('touchend', (event) => {
            const now = (new Date()).getTime();
            if (now - lastTouchEnd <= 300) {
                event.preventDefault();
            }
            lastTouchEnd = now;
        }, false);

        // Add loading states for better perceived performance
        this.setupLoadingStates();
    }

    handleResize() {
        const isMobile = window.innerWidth <= 768;
        
        // Adjust particle system based on screen size
        if (isMobile !== this.wasMobile) {
            this.setupParticles();
            this.wasMobile = isMobile;
        }

        // Update demo screen dimensions
        const demoScreen = document.querySelector('.demo-screen');
        if (demoScreen && isMobile) {
            demoScreen.style.height = Math.min(250, window.innerHeight * 0.3) + 'px';
        }
    }

    updateScrollEffects() {
        // Simplified scroll effects for mobile
        const scrolled = window.pageYOffset;
        const hero = document.querySelector('.hero-background');
        
        if (hero && window.innerWidth > 768) {
            hero.style.transform = `translateY(${scrolled * 0.1}px)`;
        }
    }

    setupLoadingStates() {
        // Add loading states to improve perceived performance
        const heavyElements = document.querySelectorAll('.demo-screen, .feature-card');
        
        heavyElements.forEach(element => {
            element.style.opacity = '0';
            element.style.transition = 'opacity 0.3s ease';
        });

        // Reveal elements progressively
        setTimeout(() => {
            heavyElements.forEach((element, index) => {
                setTimeout(() => {
                    element.style.opacity = '1';
                }, index * 100);
            });
        }, 500);
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
        
        // Detect mobile devices
        const isMobile = window.innerWidth <= 768;
        const particleCount = isMobile ? 15 : 30; // Fewer particles on mobile

        // Clear existing particles
        particleContainer.innerHTML = '';

        // Create neural network nodes
        for (let i = 0; i < particleCount; i++) {
            const particle = document.createElement('div');
            particle.className = 'particle';
            
            const size = isMobile ? Math.random() * 4 + 2 : Math.random() * 6 + 2;
            const x = Math.random() * 100;
            const y = Math.random() * 100;
            const hue = Math.random() * 60 + 220; // Blue to purple range
            const animationDuration = isMobile ? Math.random() * 20 + 15 : Math.random() * 15 + 10;
            
            particle.style.cssText = `
                position: absolute;
                width: ${size}px;
                height: ${size}px;
                background: radial-gradient(circle, hsl(${hue}, 70%, 60%), transparent);
                border-radius: 50%;
                top: ${y}%;
                left: ${x}%;
                animation: particleFloat ${animationDuration}s ease-in-out infinite;
                animation-delay: ${Math.random() * 5}s;
                opacity: ${isMobile ? Math.random() * 0.6 + 0.2 : Math.random() * 0.8 + 0.2};
                box-shadow: 0 0 ${size * 3}px hsla(${hue}, 70%, 60%, 0.5);
                pointer-events: none;
                z-index: 1;
            `;
            
            particleContainer.appendChild(particle);
        }

        // Create neural connections (fewer on mobile)
        this.createNeuralConnections(particleContainer, isMobile);

        // Add advanced particle animation CSS
        this.addParticleStyles();
    }

    createNeuralConnections(container, isMobile = false) {
        const connectionCount = isMobile ? 4 : 8; // Fewer connections on mobile
        
        for (let i = 0; i < connectionCount; i++) {
            const connection = document.createElement('div');
            connection.className = 'neural-connection';
            
            const startX = Math.random() * 80 + 10;
            const startY = Math.random() * 80 + 10;
            const endX = Math.random() * 80 + 10;
            const endY = Math.random() * 80 + 10;
            
            const length = Math.sqrt(Math.pow(endX - startX, 2) + Math.pow(endY - startY, 2));
            const angle = Math.atan2(endY - startY, endX - startX) * 180 / Math.PI;
            
            connection.style.cssText = `
                position: absolute;
                left: ${startX}%;
                top: ${startY}%;
                width: ${length}%;
                height: ${isMobile ? 1 : 2}px;
                background: linear-gradient(90deg, 
                    rgba(99, 102, 241, 0.1) 0%,
                    rgba(139, 92, 246, ${isMobile ? 0.4 : 0.6}) 50%,
                    rgba(99, 102, 241, 0.1) 100%);
                transform-origin: left center;
                transform: rotate(${angle}deg);
                animation: connectionPulse ${Math.random() * 6 + 4}s ease-in-out infinite;
                animation-delay: ${Math.random() * 2}s;
                opacity: ${isMobile ? 0.5 : 0.7};
                pointer-events: none;
                z-index: 0;
            `;
            
            container.appendChild(connection);
        }
    }

    addParticleStyles() {
        const style = document.createElement('style');
        style.textContent = `
            @keyframes particleFloat {
                0%, 100% { 
                    transform: translateY(0) translateX(0) rotate(0deg) scale(1);
                    opacity: 0.3;
                }
                25% { 
                    transform: translateY(-30px) translateX(20px) rotate(90deg) scale(1.2);
                    opacity: 0.8;
                }
                50% { 
                    transform: translateY(-15px) translateX(-15px) rotate(180deg) scale(0.8);
                    opacity: 1;
                }
                75% { 
                    transform: translateY(-40px) translateX(10px) rotate(270deg) scale(1.1);
                    opacity: 0.6;
                }
            }
            
            @keyframes connectionPulse {
                0%, 100% {
                    opacity: 0.2;
                    background: linear-gradient(90deg, 
                        rgba(99, 102, 241, 0.1) 0%,
                        rgba(139, 92, 246, 0.3) 50%,
                        rgba(99, 102, 241, 0.1) 100%);
                }
                50% {
                    opacity: 0.8;
                    background: linear-gradient(90deg, 
                        rgba(99, 102, 241, 0.2) 0%,
                        rgba(139, 92, 246, 0.9) 50%,
                        rgba(99, 102, 241, 0.2) 100%);
                    box-shadow: 0 0 10px rgba(139, 92, 246, 0.5);
                }
            }
        `;
        document.head.appendChild(style);
    }

    // Advanced Mouse Effects
    setupMouseEffects() {
        const isMobile = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
        
        // Skip mouse effects on touch devices
        if (isMobile) {
            this.setupTouchEffects();
            return;
        }

        const hero = document.querySelector('.hero');
        const cursor = document.createElement('div');
        cursor.className = 'futuristic-cursor';
        cursor.style.cssText = `
            position: fixed;
            width: 20px;
            height: 20px;
            border: 2px solid rgba(99, 102, 241, 0.8);
            border-radius: 50%;
            pointer-events: none;
            z-index: 9999;
            mix-blend-mode: difference;
            transition: transform 0.1s ease;
        `;
        document.body.appendChild(cursor);

        let mouseX = 0, mouseY = 0;
        let cursorX = 0, cursorY = 0;

        document.addEventListener('mousemove', (e) => {
            mouseX = e.clientX;
            mouseY = e.clientY;

            // Magnetic effect for buttons (only on desktop)
            const buttons = document.querySelectorAll('.cta-button');
            buttons.forEach(button => {
                const rect = button.getBoundingClientRect();
                const buttonCenterX = rect.left + rect.width / 2;
                const buttonCenterY = rect.top + rect.height / 2;
                const distance = Math.sqrt(
                    Math.pow(mouseX - buttonCenterX, 2) + 
                    Math.pow(mouseY - buttonCenterY, 2)
                );

                if (distance < 100) {
                    const strength = (100 - distance) / 100;
                    const deltaX = (mouseX - buttonCenterX) * strength * 0.1;
                    const deltaY = (mouseY - buttonCenterY) * strength * 0.1;
                    button.style.transform = `translate(${deltaX}px, ${deltaY}px) scale(${1 + strength * 0.05})`;
                } else {
                    button.style.transform = '';
                }
            });
        });

        // Smooth cursor animation
        const animateCursor = () => {
            cursorX += (mouseX - cursorX) * 0.1;
            cursorY += (mouseY - cursorY) * 0.1;
            cursor.style.left = cursorX + 'px';
            cursor.style.top = cursorY + 'px';
            requestAnimationFrame(animateCursor);
        };
        animateCursor();
    }

    // Touch Effects for Mobile
    setupTouchEffects() {
        const buttons = document.querySelectorAll('.cta-button, .demo-btn');
        
        buttons.forEach(button => {
            button.addEventListener('touchstart', (e) => {
                e.preventDefault();
                button.style.transform = 'scale(0.95)';
                button.style.transition = 'transform 0.1s ease';
                
                // Create ripple effect
                const ripple = document.createElement('div');
                const rect = button.getBoundingClientRect();
                const size = Math.max(rect.width, rect.height);
                const x = e.touches[0].clientX - rect.left - size / 2;
                const y = e.touches[0].clientY - rect.top - size / 2;
                
                ripple.style.cssText = `
                    position: absolute;
                    width: ${size}px;
                    height: ${size}px;
                    border-radius: 50%;
                    background: rgba(99, 102, 241, 0.3);
                    left: ${x}px;
                    top: ${y}px;
                    transform: scale(0);
                    animation: ripple 0.6s ease-out;
                    pointer-events: none;
                `;
                
                button.style.position = 'relative';
                button.style.overflow = 'hidden';
                button.appendChild(ripple);
                
                setTimeout(() => {
                    if (ripple.parentNode) {
                        ripple.parentNode.removeChild(ripple);
                    }
                }, 600);
            });
            
            button.addEventListener('touchend', () => {
                button.style.transform = '';
            });
        });

        // Add ripple animation CSS
        const style = document.createElement('style');
        style.textContent = `
            @keyframes ripple {
                to {
                    transform: scale(2);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(style);
    }

    // Advanced Animations Controller
    setupAdvancedAnimations() {
        const isMobile = window.innerWidth <= 768;
        
        // Parallax effect on hero background (reduced on mobile)
        window.addEventListener('scroll', this.throttle(() => {
            const scrolled = window.pageYOffset;
            const hero = document.querySelector('.hero-background');
            const title = document.querySelector('.hero-title');
            
            if (hero) {
                const parallaxSpeed = isMobile ? 0.1 : 0.3; // Reduced parallax on mobile
                hero.style.transform = `translateY(${scrolled * parallaxSpeed}px)`;
            }
            
            if (title && scrolled < window.innerHeight) {
                const opacity = 1 - (scrolled / window.innerHeight);
                title.style.opacity = Math.max(0.3, opacity);
            }
        }, isMobile ? 16 : 10)); // Longer throttle on mobile for better performance

        // Interactive window demo (simplified on mobile)
        const demoScreen = document.querySelector('.demo-screen');
        const demoWindows = document.querySelectorAll('.demo-window');
        
        if (demoScreen && !isMobile) {
            // Full 3D effects only on desktop
            demoScreen.addEventListener('mousemove', (e) => {
                const rect = demoScreen.getBoundingClientRect();
                const x = (e.clientX - rect.left) / rect.width - 0.5;
                const y = (e.clientY - rect.top) / rect.height - 0.5;
                
                demoScreen.style.transform = `
                    perspective(1000px) 
                    rotateX(${y * 10}deg) 
                    rotateY(${x * 10}deg)
                    translateZ(10px)
                `;
                
                demoWindows.forEach((window, index) => {
                    const delay = index * 0.1;
                    setTimeout(() => {
                        window.style.transform = `
                            translateZ(${20 + index * 10}px)
                            rotateX(${y * 5}deg)
                            rotateY(${x * 5}deg)
                        `;
                    }, delay * 1000);
                });
            });

            demoScreen.addEventListener('mouseleave', () => {
                demoScreen.style.transform = '';
                demoWindows.forEach(window => {
                    window.style.transform = '';
                });
            });
        } else if (demoScreen && isMobile) {
            // Simple touch interactions for mobile
            demoScreen.addEventListener('touchstart', (e) => {
                e.preventDefault();
                demoScreen.style.transform = 'scale(0.98)';
                demoScreen.style.transition = 'transform 0.2s ease';
            });
            
            demoScreen.addEventListener('touchend', () => {
                demoScreen.style.transform = '';
            });
        }

        // Mobile-specific optimizations
        if (isMobile) {
            // Reduce animation complexity on mobile
            const morphingElements = document.querySelectorAll('.hero-background::before, .hero-background::after');
            morphingElements.forEach(el => {
                if (el.style) {
                    el.style.animationDuration = '20s'; // Slower animations
                }
            });

            // Pause expensive animations when page is not visible
            document.addEventListener('visibilitychange', () => {
                const particles = document.querySelectorAll('.particle, .neural-connection');
                if (document.hidden) {
                    particles.forEach(p => p.style.animationPlayState = 'paused');
                } else {
                    particles.forEach(p => p.style.animationPlayState = 'running');
                }
            });
        }
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
    
    // Floating Elements Setup
    setupFloatingElements() {
        const floatingElements = document.querySelectorAll('.floating-terminal, .floating-code, .floating-stats, .floating-ui');
        
        floatingElements.forEach((element, index) => {
            // Add random movement variations
            const randomDelay = Math.random() * 2;
            const randomDuration = 3 + Math.random() * 2;
            
            element.style.animationDelay = `${randomDelay}s`;
            element.style.animationDuration = `${randomDuration}s`;
            
            // Add interactive hover effects
            element.addEventListener('mouseenter', () => {
                element.style.animationPlayState = 'paused';
                element.style.transform = 'scale(1.1) translateY(-10px)';
                element.style.transition = 'transform 0.3s ease-out';
            });
            
            element.addEventListener('mouseleave', () => {
                element.style.animationPlayState = 'running';
                element.style.transform = '';
                element.style.transition = 'transform 0.3s ease-out';
            });
        });
        
        // Add floating particle effects
        this.createFloatingParticles();
    }
    
    // Character Animation Setup
    setupCharacterAnimations() {
        const charElements = document.querySelectorAll('.char-animate');
        
        charElements.forEach((element, elementIndex) => {
            const text = element.textContent;
            element.innerHTML = '';
            
            // Split text into individual characters
            text.split('').forEach((char, charIndex) => {
                const span = document.createElement('span');
                span.textContent = char === ' ' ? '\u00A0' : char; // Non-breaking space
                span.style.display = 'inline-block';
                span.style.opacity = '0';
                span.style.transform = 'translateY(50px) rotateX(90deg)';
                span.style.transition = `all 0.6s ease-out ${(charIndex * 0.05)}s`;
                element.appendChild(span);
            });
            
            // Trigger animation when in view
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const spans = entry.target.querySelectorAll('span');
                        spans.forEach((span, index) => {
                            setTimeout(() => {
                                span.style.opacity = '1';
                                span.style.transform = 'translateY(0) rotateX(0deg)';
                            }, index * 50);
                        });
                        observer.unobserve(entry.target);
                    }
                });
            }, { threshold: 0.3 });
            
            observer.observe(element);
        });
    }
    
    // Create floating particles for enhanced visual effect
    createFloatingParticles() {
        const hero = document.querySelector('.hero');
        const particleCount = window.innerWidth < 768 ? 15 : 30;
        
        for (let i = 0; i < particleCount; i++) {
            const particle = document.createElement('div');
            particle.className = 'floating-particle';
            particle.style.cssText = `
                position: absolute;
                width: ${Math.random() * 6 + 2}px;
                height: ${Math.random() * 6 + 2}px;
                background: linear-gradient(45deg, #00ff88, #0088ff);
                border-radius: 50%;
                pointer-events: none;
                left: ${Math.random() * 100}%;
                top: ${Math.random() * 100}%;
                opacity: ${Math.random() * 0.7 + 0.3};
                animation: floatParticle ${Math.random() * 10 + 10}s linear infinite;
                box-shadow: 0 0 ${Math.random() * 10 + 5}px rgba(0, 255, 136, 0.5);
                z-index: 1;
            `;
            hero.appendChild(particle);
        }
        
        // Add floating particle keyframes if not already added
        if (!document.querySelector('#floating-particle-styles')) {
            const style = document.createElement('style');
            style.id = 'floating-particle-styles';
            style.textContent = `
                @keyframes floatParticle {
                    0% {
                        transform: translateY(0) translateX(0) rotate(0deg);
                        opacity: 0;
                    }
                    10% {
                        opacity: 1;
                    }
                    90% {
                        opacity: 1;
                    }
                    100% {
                        transform: translateY(-100vh) translateX(${Math.random() * 200 - 100}px) rotate(360deg);
                        opacity: 0;
                    }
                }
            `;
            document.head.appendChild(style);
        }
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
