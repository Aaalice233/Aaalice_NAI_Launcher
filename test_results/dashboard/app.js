/* ============================================
   Verification Dashboard Application
   NovelAI Universal Launcher
   ============================================ */

// Global state
let testData = null;
let previousTestData = null;
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
            // Previous results not available, that's okay
            console.log('No previous test results available for regression detection');
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
                    ${fileResult.tests.map(test => `
                        <div class="test-result ${test.status}" onclick="showTestDetails('${encodeURIComponent(JSON.stringify(test))}', '${fileResult.file}')">
                            <div class="test-status ${test.status}"></div>
                            <div class="test-info">
                                <div class="test-name">${test.name}</div>
                                ${test.bugId ? `<div class="test-bug-id">${test.bugId}</div>` : ''}
                                ${test.duration ? `<div class="test-duration">${test.duration}ms</div>` : ''}
                            </div>
                            ${test.error ? `<div class="test-error">${test.error}</div>` : ''}
                        </div>
                    `).join('')}
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

        let html = `
            <div class="test-detail-section">
                <h3>Test Information</h3>
                <table class="detail-table">
                    <tr><th>File:</th><td>${fileName}</td></tr>
                    ${test.bugId ? `<tr><th>BUG ID:</th><td>${test.bugId}</td></tr>` : ''}
                    <tr><th>Status:</th><td><span class="status-badge ${test.status}">${test.status.toUpperCase()}</span></td></tr>
                    ${test.duration ? `<tr><th>Duration:</th><td>${test.duration}ms</td></tr>` : ''}
                    ${test.startTime ? `<tr><th>Start Time:</th><td>${new Date(test.startTime).toLocaleString()}</td></tr>` : ''}
                </table>
            </div>
        `;

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
function updateEvidenceCounts() {
    // Placeholder counts - in real implementation, these would be calculated
    // from actual files in the directories
    document.getElementById('screenshot-count').textContent = 'Not implemented';
    document.getElementById('log-count').textContent = `${testData.resultsByFile ? testData.resultsByFile.length : 0} files`;
    document.getElementById('fixture-count').textContent = 'Not implemented';
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
    // Placeholder - coverage data would come from coverage/lcov.info
    // In real implementation, parse lcov.info and calculate coverage
    document.getElementById('overall-coverage').textContent = 'N/A';
    document.getElementById('overall-coverage-bar').style.width = '0%';
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
