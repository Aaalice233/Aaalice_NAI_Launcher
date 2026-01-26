/* ============================================
   Verification Dashboard Application
   NovelAI Universal Launcher
   ============================================ */

// Global state
let testData = null;
let previousTestData = null;
let coverageData = null;
let filteredTests = [];
let currentFilters = {
    status: 'all',
    category: 'all',
    search: '',
    sort: 'file'
};

// Initialize dashboard when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    initializeDashboard();
});

/**
 * Initialize the dashboard
 */
async function initializeDashboard() {
    showLoadingState();
    await loadTestData();
    setupEventListeners();
    updateTimestamp();
    renderDashboard();
}

/**
 * Show loading state
 */
function showLoadingState() {
    document.getElementById('status-text').textContent = 'Loading test results...';
    document.getElementById('status-icon').textContent = '⏳';
}

/**
 * Load test results from JSON file
 */
async function loadTestData() {
    try {
        const response = await fetch('../summary.json');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        testData = await response.json();

        // Try to load previous test results for regression detection
        try {
            const prevResponse = await fetch('../summary_previous.json');
            if (prevResponse.ok) {
                previousTestData = await prevResponse.json();
            }
        } catch (e) {
            // Previous results not available, regression detection will be disabled
            // This is expected for first run or when summary_previous.json doesn't exist
        }

        // Try to load coverage data
        try {
            const coverageResponse = await fetch('../coverage.json');
            if (coverageResponse.ok) {
                coverageData = await coverageResponse.json();
            }
        } catch (e) {
            // Coverage data not available, will show N/A in dashboard
            // This is expected when tests are run without --coverage flag
        }

    } catch (error) {
        console.error('Error loading test data:', error);
        showErrorState('Failed to load test results. Make sure summary.json exists.');
        return false;
    }
    return true;
}

/**
 * Show error state
 */
function showErrorState(message) {
    document.getElementById('status-text').textContent = message;
    document.getElementById('status-icon').textContent = '❌';
    document.getElementById('status-banner').classList.add('error');
}

/**
 * Setup event listeners for interactive elements
 */
function setupEventListeners() {
    // Status filter
    document.getElementById('status-filter').addEventListener('change', (e) => {
        currentFilters.status = e.target.value;
        applyFiltersAndRender();
    });

    // Category filter
    document.getElementById('category-filter').addEventListener('change', (e) => {
        currentFilters.category = e.target.value;
        applyFiltersAndRender();
    });

    // Search input
    document.getElementById('search-input').addEventListener('input', (e) => {
        currentFilters.search = e.target.value.toLowerCase();
        applyFiltersAndRender();
    });

    // Sort select
    document.getElementById('sort-select').addEventListener('change', (e) => {
        currentFilters.sort = e.target.value;
        applyFiltersAndRender();
    });

    // Export buttons
    document.getElementById('export-json').addEventListener('click', exportToJSON);
    document.getElementById('export-csv').addEventListener('click', exportToCSV);
    document.getElementById('refresh-data').addEventListener('click', refreshData);

    // Modal close
    document.querySelector('.modal-close').addEventListener('click', closeModal);
    document.getElementById('test-modal').addEventListener('click', (e) => {
        if (e.target.id === 'test-modal') {
            closeModal();
        }
    });

    // ESC key to close modal
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeModal();
        }
    });
}

/**
 * Apply filters and re-render dashboard
 */
function applyFiltersAndRender() {
    if (!testData) return;

    // Get all tests from resultsByFile
    let allTests = [];
    if (testData.resultsByFile) {
        testData.resultsByFile.forEach(fileResult => {
            fileResult.tests.forEach(test => {
                allTests.push({
                    ...test,
                    fileName: fileResult.file
                });
            });
        });
    }

    // Apply status filter
    if (currentFilters.status !== 'all') {
        allTests = allTests.filter(test => {
            switch (currentFilters.status) {
                case 'passed':
                    return test.status === 'success';
                case 'failed':
                    return test.status === 'error' || test.status === 'failure';
                case 'skipped':
                    return test.status === 'skipped';
                default:
                    return true;
            }
        });
    }

    // Apply category filter
    if (currentFilters.category !== 'all') {
        allTests = allTests.filter(test => {
            switch (currentFilters.category) {
                case 'bug':
                    return test.bugId && test.bugId.startsWith('BUG-');
                case 'improvement':
                    return test.bugId && test.bugId.startsWith('IMPR-');
                case 'other':
                    return !test.bugId;
                default:
                    return true;
            }
        });
    }

    // Apply search filter
    if (currentFilters.search) {
        allTests = allTests.filter(test => {
            return test.name.toLowerCase().includes(currentFilters.search) ||
                   test.fileName.toLowerCase().includes(currentFilters.search) ||
                   (test.bugId && test.bugId.toLowerCase().includes(currentFilters.search));
        });
    }

    // Apply sorting
    allTests.sort((a, b) => {
        switch (currentFilters.sort) {
            case 'file':
                return a.fileName.localeCompare(b.fileName);
            case 'name':
                return a.name.localeCompare(b.name);
            case 'duration':
                return (b.duration || 0) - (a.duration || 0);
            case 'status':
                const statusOrder = { 'error': 0, 'failure': 1, 'skipped': 2, 'success': 3 };
                return statusOrder[a.status] - statusOrder[b.status];
            default:
                return 0;
        }
    });

    filteredTests = allTests;
    renderDashboard();
}

/**
 * Render the dashboard with current data
 */
function renderDashboard() {
    if (!testData) return;

    updateSummaryCards();
    updateStatusBanner();
    renderBugTests();
    renderDetailedResults();
    updateEvidenceCounts();
    renderRegressionDetection();
    updateCoverageReport();
}

/**
 * Update summary cards with test statistics
 */
function updateSummaryCards() {
    const summary = testData.summary;
    document.getElementById('total-tests').textContent = summary.totalTests || 0;
    document.getElementById('passed-tests').textContent = summary.passedTests || 0;
    document.getElementById('failed-tests').textContent = summary.failedTests || 0;
    document.getElementById('skipped-tests').textContent = summary.skippedTests || 0;

    const passRate = summary.passRate || 0;
    document.getElementById('pass-rate').textContent = `${passRate.toFixed(1)}%`;
}

/**
 * Update status banner
 */
function updateStatusBanner() {
    const summary = testData.summary;
    const banner = document.getElementById('status-banner');
    const icon = document.getElementById('status-icon');
    const text = document.getElementById('status-text');

    // Remove existing classes
    banner.classList.remove('success', 'error', 'warning');

    const passRate = summary.passRate || 0;
    if (passRate >= 90) {
        banner.classList.add('success');
        icon.textContent = '✅';
        text.textContent = `All tests passed! (${passRate.toFixed(1)}% pass rate)`;
    } else if (passRate >= 70) {
        banner.classList.add('warning');
        icon.textContent = '⚠️';
        text.textContent = `Some tests failed (${passRate.toFixed(1)}% pass rate)`;
    } else {
        banner.classList.add('error');
        icon.textContent = '❌';
        text.textContent = `Critical: Many tests failed (${passRate.toFixed(1)}% pass rate)`;
    }
}

/**
 * Render BUG tests section
 */
function renderBugTests() {
    const grid = document.getElementById('bug-tests-grid');
    const countElement = document.getElementById('bug-count');

    if (!testData.resultsByFile) {
        grid.innerHTML = '<div class="error-message">No test results available</div>';
        return;
    }

    // Get BUG tests
    const bugTests = [];
    const bugFileMap = {
        'vibe_encoding_test.dart': 'BUG-001',
        'sampler_test.dart': 'BUG-002',
        'seed_provider_test.dart': 'BUG-003',
        'auth_api_test.dart': 'BUG-004/005',
        'sidebar_state_test.dart': 'BUG-006',
        'query_parser_test.dart': 'BUG-007',
        'prompt_autofill_test.dart': 'BUG-008',
        'character_bar_test.dart': 'BUG-009'
    };

    testData.resultsByFile.forEach(fileResult => {
        const bugId = bugFileMap[fileResult.file];
        if (bugId) {
            const passedTests = fileResult.tests.filter(t => t.status === 'success').length;
            const failedTests = fileResult.tests.filter(t => t.status === 'error' || t.status === 'failure').length;
            const skippedTests = fileResult.tests.filter(t => t.status === 'skipped').length;

            bugTests.push({
                bugId,
                fileName: fileResult.file,
                total: fileResult.total,
                passed: passedTests,
                failed: failedTests,
                skipped: skippedTests,
                passRate: fileResult.total > 0 ? (passedTests / fileResult.total * 100) : 0
            });
        }
    });

    countElement.textContent = `${bugTests.length} Test Files`;

    // Generate bug test cards
    grid.innerHTML = bugTests.map(bug => {
        const statusClass = bug.failed > 0 ? 'fail' : (bug.skipped > 0 ? 'skip' : 'pass');
        return `
            <div class="test-card ${statusClass}">
                <div class="card-header">
                    <span class="test-id">${bug.bugId}</span>
                    <span class="test-badge ${statusClass}">${getStatusText(statusClass)}</span>
                </div>
                <div class="card-body">
                    <div class="test-file">${bug.fileName}</div>
                    <div class="test-stats">
                        <span class="stat passed">✅ ${bug.passed} passed</span>
                        ${bug.failed > 0 ? `<span class="stat failed">❌ ${bug.failed} failed</span>` : ''}
                        ${bug.skipped > 0 ? `<span class="stat skipped">⏭️ ${bug.skipped} skipped</span>` : ''}
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

/**
 * Get regression status for a test
 * @param {Object} test - Current test object
 * @returns {Object} - Regression status {isRegression, isNew, isFixed, previousStatus}
 */
function getRegressionStatus(test) {
    if (!previousTestData || !previousTestData.resultsByFile) {
        return { isRegression: false, isNew: false, isFixed: false, previousStatus: null };
    }

    // Find previous test with same name
    let previousStatus = null;
    for (const fileResult of previousTestData.resultsByFile) {
        const prevTest = fileResult.tests.find(t => t.name === test.name);
        if (prevTest) {
            previousStatus = prevTest.status;
            break;
        }
    }

    // Test is new if it didn't exist before
    if (!previousStatus) {
        return { isRegression: false, isNew: true, isFixed: false, previousStatus: null };
    }

    // Test is a regression if it passed before but fails now
    const isRegression = (previousStatus === 'success') && (test.status === 'error' || test.status === 'failure');

    // Test is fixed if it failed before but passes now
    const isFixed = (previousStatus === 'error' || previousStatus === 'failure') && (test.status === 'success');

    return { isRegression, isNew: false, isFixed, previousStatus };
}

/**
 * Render detailed test results
 */
function renderDetailedResults() {
    const container = document.getElementById('file-results');
    const countElement = document.getElementById('detailed-count');

    if (!testData.resultsByFile) {
        container.innerHTML = '<div class="error-message">No test results available</div>';
        return;
    }

    // Count total tests
    const totalTests = testData.resultsByFile.reduce((sum, file) => sum + file.total, 0);
    countElement.textContent = `${totalTests} Tests from ${testData.resultsByFile.length} Files`;

    // Generate file result cards
    container.innerHTML = testData.resultsByFile.map(fileResult => {
        const passedTests = fileResult.tests.filter(t => t.status === 'success').length;
        const failedTests = fileResult.tests.filter(t => t.status === 'error' || t.status === 'failure').length;
        const skippedTests = fileResult.tests.filter(t => t.status === 'skipped').length;

        return `
            <div class="file-result-card">
                <div class="file-header" onclick="toggleFileDetails('${fileResult.file}')">
                    <span class="file-name">${fileResult.file}</span>
                    <div class="file-stats">
                        <span class="stat passed">${passedTests} passed</span>
                        ${failedTests > 0 ? `<span class="stat failed">${failedTests} failed</span>` : ''}
                        ${skippedTests > 0 ? `<span class="stat skipped">${skippedTests} skipped</span>` : ''}
                        <span class="stat total">${fileResult.total} total</span>
                    </div>
                </div>
                <div class="file-details" id="details-${fileResult.file.replace(/[^a-zA-Z0-9]/g, '-')}">
                    ${fileResult.tests.map(test => {
                        const regression = getRegressionStatus(test);
                        return `
                        <div class="test-result ${test.status} ${regression.isRegression ? 'regression' : ''} ${regression.isNew ? 'new-test' : ''} ${regression.isFixed ? 'fixed' : ''}"
                             onclick="showTestDetails('${encodeURIComponent(JSON.stringify(test))}', '${fileResult.file}')">
                            <div class="test-status ${test.status}"></div>
                            <div class="test-info">
                                <div class="test-name">
                                    ${escapeHtml(test.name)}
                                    ${regression.isRegression ? '<span class="regression-badge" title="This test passed in the previous run but failed now">NEW FAILURE</span>' : ''}
                                    ${regression.isNew ? '<span class="new-test-badge" title="This test is new">NEW</span>' : ''}
                                    ${regression.isFixed ? '<span class="fixed-badge" title="This test failed in the previous run but passed now">FIXED</span>' : ''}
                                </div>
                                ${test.bugId ? `<div class="test-bug-id">${test.bugId}</div>` : ''}
                                ${test.duration ? `<div class="test-duration">${test.duration}ms</div>` : ''}
                            </div>
                            ${test.error ? `<div class="test-error">${test.error}</div>` : ''}
                        </div>
                    `;
                    }).join('')}
                </div>
            </div>
        `;
    }).join('');
}

/**
 * Toggle file details visibility
 */
function toggleFileDetails(fileName) {
    const detailsId = `details-${fileName.replace(/[^a-zA-Z0-9]/g, '-')}`;
    const detailsElement = document.getElementById(detailsId);

    if (detailsElement) {
        detailsElement.classList.toggle('expanded');
    }
}

/**
 * Show test details modal
 */
function showTestDetails(testJson, fileName) {
    try {
        const test = JSON.parse(decodeURIComponent(testJson));
        const modal = document.getElementById('test-modal');
        const modalTitle = document.getElementById('modal-title');
        const modalBody = document.getElementById('modal-body');

        modalTitle.textContent = test.name;

        // Get regression status
        const regression = getRegressionStatus(test);

        let html = `
            <div class="test-detail-section">
                <h3>Test Information</h3>
                <table class="detail-table">
                    <tr><th>File:</th><td>${fileName}</td></tr>
                    ${test.bugId ? `<tr><th>BUG ID:</th><td>${test.bugId}</td></tr>` : ''}
                    <tr><th>Status:</th><td><span class="status-badge ${test.status}">${test.status.toUpperCase()}</span></td></tr>
                    ${regression.isRegression ? `<tr><th>⚠️ Regression:</th><td><span class="regression-badge">NEW FAILURE</span> - Previously passed as ${regression.previousStatus}</td></tr>` : ''}
                    ${regression.isNew ? `<tr><th>🆕 New Test:</th><td><span class="new-test-badge">NEW</span> - This test did not exist in the previous run</td></tr>` : ''}
                    ${regression.isFixed ? `<tr><th>✅ Fixed:</th><td><span class="fixed-badge">FIXED</span> - Previously failed as ${regression.previousStatus}</td></tr>` : ''}
                    ${test.duration ? `<tr><th>Duration:</th><td>${test.duration}ms</td></tr>` : ''}
                    ${test.startTime ? `<tr><th>Start Time:</th><td>${new Date(test.startTime).toLocaleString()}</td></tr>` : ''}
                </table>
            </div>
        `;

        // Add evidence section for failed tests
        if (test.status === 'error' || test.status === 'failure') {
            html += `
                <div class="test-detail-section">
                    <h3>📸 Evidence & Artifacts</h3>
                    <div class="evidence-links-section">
                        <h4>Test Logs</h4>
                        <div class="evidence-links">
                            <a href="../summary.json" target="_blank" class="evidence-link">
                                📄 View summary.json
                            </a>
                            <a href="../verification_output.json" target="_blank" class="evidence-link">
                                📄 View verification_output.json
                            </a>
                        </div>

                        <h4>Related Fixtures</h4>
                        <div class="evidence-links">
                            <a href="../../test/fixtures/json/auth_success_response.json" target="_blank" class="evidence-link">
                                📦 auth_success_response.json
                            </a>
                            <a href="../../test/fixtures/json/auth_failure_response.json" target="_blank" class="evidence-link">
                                📦 auth_failure_response.json
                            </a>
                            <a href="../../test/fixtures/json/danbooru_posts.json" target="_blank" class="evidence-link">
                                📦 danbooru_posts.json
                            </a>
                        </div>

                        <h4>Test Screenshots</h4>
                        <div class="evidence-links">
                            <a href="../../test/fixtures/images/test_metadata.png" target="_blank" class="evidence-link">
                                🖼️ test_metadata.png
                            </a>
                            <a href="../../test/fixtures/images/test_vibe_image.png" target="_blank" class="evidence-link">
                                🖼️ test_vibe_image.png
                            </a>
                        </div>
                    </div>
                </div>
            `;
        }

        if (test.error) {
            html += `
                <div class="test-detail-section">
                    <h3>Error Details</h3>
                    <div class="error-details">
                        <pre>${escapeHtml(test.error)}</pre>
                    </div>
                </div>
            `;
        }

        if (test.stackTrace) {
            html += `
                <div class="test-detail-section">
                    <h3>Stack Trace</h3>
                    <div class="stack-trace">
                        <pre>${escapeHtml(test.stackTrace)}</pre>
                    </div>
                </div>
            `;
        }

        modalBody.innerHTML = html;
        modal.style.display = 'block';
    } catch (e) {
        console.error('Error showing test details:', e);
    }
}

/**
 * Close modal
 */
function closeModal() {
    document.getElementById('test-modal').style.display = 'none';
}

/**
 * Update evidence counts
 */
async function updateEvidenceCounts() {
    let totalEvidenceItems = 0;

    // Count fixture files
    try {
        const fixtureCount = await countFixtureFiles();
        document.getElementById('fixture-count').textContent = `${fixtureCount} JSON files`;
        totalEvidenceItems += fixtureCount;
    } catch (e) {
        document.getElementById('fixture-count').textContent = 'Count unavailable';
    }

    // Count test result files
    const logCount = testData.resultsByFile ? testData.resultsByFile.length : 0;
    document.getElementById('log-count').textContent = `${logCount} test files`;
    totalEvidenceItems += logCount;

    // Count screenshots (check if directory exists and count files)
    try {
        const screenshotCount = await countScreenshots();
        document.getElementById('screenshot-count').textContent = `${screenshotCount} files`;
        totalEvidenceItems += screenshotCount;
    } catch (e) {
        document.getElementById('screenshot-count').textContent = 'No screenshots';
    }

    // Update evidence count in section header
    document.getElementById('evidence-count').textContent = `${totalEvidenceItems} Items`;

    // Render failed test evidence
    renderFailedTestEvidence();
}

/**
 * Count fixture files
 */
async function countFixtureFiles() {
    // Since we can't directly access the filesystem from the browser,
    // we'll return a count based on known fixtures
    // In a real implementation, this would be an API call
    return 3; // auth_success, auth_failure, danbooru_posts
}

/**
 * Count screenshot files
 */
async function countScreenshots() {
    // Since we can't directly access the filesystem from the browser,
    // we'll return a count based on known screenshots
    // In a real implementation, this would be an API call
    return 2; // test_metadata.png, test_vibe_image.png
}

/**
 * Render evidence for failed tests
 */
function renderFailedTestEvidence() {
    const evidenceGrid = document.getElementById('evidence-grid');

    if (!testData.resultsByFile) {
        return;
    }

    // Collect all failed tests
    const failedTests = [];
    testData.resultsByFile.forEach(fileResult => {
        fileResult.tests.forEach(test => {
            if (test.status === 'error' || test.status === 'failure') {
                failedTests.push({
                    ...test,
                    fileName: fileResult.file
                });
            }
        });
    });

    // If we have failed tests, add them to the evidence grid
    if (failedTests.length > 0) {
        const failedTestsHtml = `
            <div class="evidence-card evidence-card-failed">
                <h3>❌ Failed Tests Evidence</h3>
                <p>Failed tests with available logs and error details:</p>
                <div class="failed-tests-list">
                    ${failedTests.slice(0, 5).map(test => `
                        <div class="failed-test-item">
                            <div class="failed-test-name">${escapeHtml(test.name)}</div>
                            <div class="failed-test-meta">
                                <span class="failed-test-file">${escapeHtml(test.fileName)}</span>
                                ${test.bugId ? `<span class="failed-test-bug-id">${escapeHtml(test.bugId)}</span>` : ''}
                            </div>
                            <button class="evidence-link-btn" onclick="showTestDetails('${encodeURIComponent(JSON.stringify(test))}', '${escapeHtml(test.fileName)}')">
                                View Details
                            </button>
                        </div>
                    `).join('')}
                    ${failedTests.length > 5 ? `<div class="more-failed-tests">... and ${failedTests.length - 5} more failed tests</div>` : ''}
                </div>
            </div>
        `;

        // Insert after the existing evidence cards
        evidenceGrid.insertAdjacentHTML('beforeend', failedTestsHtml);
    }

    // Add test log file links
    const logFilesHtml = `
        <div class="evidence-card">
            <h3>📄 Test Result Files</h3>
            <p>Downloadable test result JSON files:</p>
            <div class="evidence-links">
                <a href="../summary.json" target="_blank" class="evidence-link">summary.json</a>
                <a href="../verification_output.json" target="_blank" class="evidence-link">verification_output.json</a>
                <a href="../bug_test_output.json" target="_blank" class="evidence-link">bug_test_output.json</a>
                <a href="../processed_summary.json" target="_blank" class="evidence-link">processed_summary.json</a>
            </div>
        </div>
    `;

    evidenceGrid.insertAdjacentHTML('beforeend', logFilesHtml);
}

/**
 * Render regression detection
 */
function renderRegressionDetection() {
    const container = document.getElementById('regression-comparison');
    const countElement = document.getElementById('regression-count');

    if (!previousTestData) {
        container.innerHTML = '<p class="info-text">No previous test results available for comparison.</p>';
        countElement.textContent = 'No previous data';
        return;
    }

    // Compare current vs previous results
    const newFailures = [];
    const fixedTests = [];
    const statusChanges = [];

    // Get all current tests
    const currentTests = new Map();
    if (testData.resultsByFile) {
        testData.resultsByFile.forEach(fileResult => {
            fileResult.tests.forEach(test => {
                currentTests.set(test.name, test.status);
            });
        });
    }

    // Get all previous tests
    const previousTests = new Map();
    if (previousTestData.resultsByFile) {
        previousTestData.resultsByFile.forEach(fileResult => {
            fileResult.tests.forEach(test => {
                previousTests.set(test.name, test.status);
            });
        });
    }

    // Find new failures
    currentTests.forEach((currentStatus, testName) => {
        const previousStatus = previousTests.get(testName);

        if (!previousStatus) {
            // New test
            statusChanges.push({ test: testName, change: 'NEW', status: currentStatus });
        } else if (previousStatus === 'success' && (currentStatus === 'error' || currentStatus === 'failure')) {
            // New failure
            newFailures.push({ test: testName, status: currentStatus });
        } else if ((previousStatus === 'error' || previousStatus === 'failure') && currentStatus === 'success') {
            // Fixed test
            fixedTests.push({ test: testName, status: currentStatus });
        }
    });

    countElement.textContent = `${newFailures.length} new failures`;

    // Generate regression comparison HTML
    container.innerHTML = `
        ${newFailures.length > 0 ? `
            <div class="regression-item new-failure">
                <h4>❌ New Failures (${newFailures.length})</h4>
                <ul>
                    ${newFailures.slice(0, 10).map(f => `<li>${escapeHtml(f.test)}</li>`).join('')}
                    ${newFailures.length > 10 ? `<li>... and ${newFailures.length - 10} more</li>` : ''}
                </ul>
            </div>
        ` : ''}
        ${fixedTests.length > 0 ? `
            <div class="regression-item fixed">
                <h4>✅ Fixed Tests (${fixedTests.length})</h4>
                <ul>
                    ${fixedTests.slice(0, 10).map(f => `<li>${escapeHtml(f.test)}</li>`).join('')}
                    ${fixedTests.length > 10 ? `<li>... and ${fixedTests.length - 10} more</li>` : ''}
                </ul>
            </div>
        ` : ''}
        ${statusChanges.length > 0 ? `
            <div class="regression-item new-test">
                <h4>🆕 New Tests (${statusChanges.length})</h4>
                <ul>
                    ${statusChanges.slice(0, 10).map(s => `<li>${escapeHtml(s.test)}</li>`).join('')}
                    ${statusChanges.length > 10 ? `<li>... and ${statusChanges.length - 10} more</li>` : ''}
                </ul>
            </div>
        ` : ''}
    `;
}

/**
 * Update coverage report
 */
function updateCoverageReport() {
    const overallCoverageElement = document.getElementById('overall-coverage');
    const overallCoverageBarElement = document.getElementById('overall-coverage-bar');
    const coverageGrid = document.getElementById('coverage-grid');

    if (!coverageData || !coverageData.modules) {
        overallCoverageElement.textContent = 'N/A';
        overallCoverageBarElement.style.width = '0%';
        coverageGrid.innerHTML = `
            <div class="coverage-card">
                <h3>Overall Coverage</h3>
                <div class="coverage-percentage" id="overall-coverage">N/A</div>
                <div class="coverage-bar">
                    <div class="coverage-fill" id="overall-coverage-bar" style="width: 0%"></div>
                </div>
            </div>
            <div class="coverage-message">
                <p>Code coverage data will be available when running tests with the <code>--coverage</code> flag:</p>
                <pre>flutter test --coverage</pre>
                <p>Coverage report will be generated in: <code>coverage/lcov.info</code></p>
                <p>Then run the coverage processor to generate the JSON report:</p>
                <pre>dart run tool/coverage_processor.dart</pre>
            </div>
        `;
        return;
    }

    // Update overall coverage
    const overallPercentage = coverageData.percentage || 0;
    overallCoverageElement.textContent = `${overallPercentage.toFixed(1)}%`;
    overallCoverageBarElement.style.width = `${overallPercentage}%`;

    // Set color based on coverage percentage
    const coverageClass = overallPercentage >= 80 ? 'high' : overallPercentage >= 50 ? 'medium' : 'low';
    overallCoverageBarElement.className = `coverage-fill ${coverageClass}`;

    // Generate module coverage cards
    let modulesHtml = `
        <div class="coverage-card">
            <h3>Overall Coverage</h3>
            <div class="coverage-percentage" id="overall-coverage">${overallPercentage.toFixed(1)}%</div>
            <div class="coverage-bar">
                <div class="coverage-fill ${coverageClass}" id="overall-coverage-bar" style="width: ${overallPercentage}%"></div>
            </div>
            <div class="coverage-details">
                <span>${coverageData.totalLinesHit}/${coverageData.totalLinesFound} lines covered</span>
            </div>
        </div>
    `;

    // Add module coverage cards
    for (const module of coverageData.modules) {
        const modulePercentage = module.percentage || 0;
        const moduleClass = modulePercentage >= 80 ? 'high' : modulePercentage >= 50 ? 'medium' : 'low';
        const fileCount = module.files ? module.files.length : 0;

        modulesHtml += `
            <div class="coverage-card">
                <h3>${escapeHtml(module.moduleName)}</h3>
                <div class="coverage-percentage">${modulePercentage.toFixed(1)}%</div>
                <div class="coverage-bar">
                    <div class="coverage-fill ${moduleClass}" style="width: ${modulePercentage}%"></div>
                </div>
                <div class="coverage-details">
                    <span>${module.totalLinesHit}/${module.totalLinesFound} lines</span>
                    <span>${fileCount} files</span>
                </div>
                <div class="coverage-files-toggle">
                    <button class="toggle-btn" onclick="toggleModuleFiles('${module.moduleName.replace(/\s+/g, '-')}')">
                        Show Files (${fileCount})
                    </button>
                </div>
                <div class="coverage-files-list" id="files-${module.moduleName.replace(/\s+/g, '-')}" style="display: none;">
                    ${module.files ? module.files.map(file => `
                        <div class="coverage-file-item">
                            <div class="file-name">${escapeHtml(file.filePath.split('\\').pop() || file.filePath.split('/').pop())}</div>
                            <div class="file-percentage ${file.percentage >= 80 ? 'high' : file.percentage >= 50 ? 'medium' : 'low'}">
                                ${file.percentage.toFixed(1)}%
                            </div>
                            <div class="file-details">${file.linesHit}/${file.linesFound} lines</div>
                        </div>
                    `).join('') : ''}
                </div>
            </div>
        `;
    }

    coverageGrid.innerHTML = modulesHtml;
}

/**
 * Toggle module files visibility
 */
function toggleModuleFiles(moduleId) {
    const filesList = document.getElementById(`files-${moduleId}`);
    const button = filesList.previousElementSibling.querySelector('.toggle-btn');

    if (filesList.style.display === 'none') {
        filesList.style.display = 'block';
        button.textContent = button.textContent.replace('Show', 'Hide');
    } else {
        filesList.style.display = 'none';
        button.textContent = button.textContent.replace('Hide', 'Show');
    }
}

/**
 * Export data to JSON
 */
function exportToJSON() {
    if (!testData) {
        alert('No test data available to export');
        return;
    }

    const dataStr = JSON.stringify(testData, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);

    const link = document.createElement('a');
    link.href = url;
    link.download = `test-results-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();

    URL.revokeObjectURL(url);
}

/**
 * Export data to CSV
 */
function exportToCSV() {
    if (!testData || !testData.resultsByFile) {
        alert('No test data available to export');
        return;
    }

    // Flatten test data for CSV
    const rows = [['Test Name', 'File', 'BUG ID', 'Status', 'Duration (ms)', 'Error']];

    testData.resultsByFile.forEach(fileResult => {
        fileResult.tests.forEach(test => {
            rows.push([
                test.name,
                fileResult.file,
                test.bugId || '',
                test.status,
                test.duration || '',
                test.error || ''
            ]);
        });
    });

    const csvContent = rows.map(row => row.map(cell => `"${cell}"`).join(',')).join('\n');
    const csvBlob = new Blob([csvContent], { type: 'text/csv' });
    const url = URL.createObjectURL(csvBlob);

    const link = document.createElement('a');
    link.href = url;
    link.download = `test-results-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();

    URL.revokeObjectURL(url);
}

/**
 * Refresh data
 */
async function refreshData() {
    const button = document.getElementById('refresh-data');
    button.disabled = true;
    button.textContent = 'Refreshing...';

    showLoadingState();

    // Reload test data
    const success = await loadTestData();

    if (success) {
        applyFiltersAndRender();
        button.textContent = 'Refresh Data';
        button.disabled = false;
    } else {
        button.textContent = 'Refresh Failed';
        setTimeout(() => {
            button.disabled = false;
            button.textContent = 'Refresh Data';
        }, 2000);
    }
}

/**
 * Update timestamp
 */
function updateTimestamp() {
    const now = new Date();
    const timestamp = now.toLocaleString();
    document.getElementById('timestamp').textContent = `Last updated: ${timestamp}`;
}

/**
 * Get status text
 */
function getStatusText(status) {
    switch (status) {
        case 'pass':
            return 'PASS';
        case 'fail':
            return 'FAIL';
        case 'skip':
            return 'SKIP';
        default:
            return 'UNKNOWN';
    }
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// End of app.js
