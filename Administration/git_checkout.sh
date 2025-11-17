#!/bin/bash

# GitLab Backup Script
# This script clones all projects from your GitLab instance to a local backup directory
# It only clones new projects and skips existing ones

# Configuration
GITLAB_URL="https://gitlab.mayer-it.net"
BACKUP_DIR="/home/chriz/Development/Gitlab_Backup"
GITLAB_TOKEN=""  # Set your GitLab Personal Access Token here
INSECURE_SSL=false  # Set to true if using self-signed SSL certificate

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if GitLab token is set
if [ -z "$GITLAB_TOKEN" ]; then
    print_error "GitLab Personal Access Token is not set!"
    print_info "Please edit this script and set the GITLAB_TOKEN variable."
    print_info "You can create a token at: ${GITLAB_URL}/-/user_settings/personal_access_tokens"
    print_info "Required scopes: read_api, read_repository"
    exit 1
fi

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    print_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Change to backup directory
cd "$BACKUP_DIR" || exit 1

print_info "Fetching project list from GitLab instance: $GITLAB_URL"

# Set curl options
CURL_OPTS=""
if [ "$INSECURE_SSL" = true ]; then
    CURL_OPTS="-k"
    print_warning "SSL certificate verification is disabled"
fi

# Test connection first
print_info "Testing connection to GitLab..."
test_response=$(curl -s -w "\n%{http_code}" $CURL_OPTS --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "${GITLAB_URL}/api/v4/version" 2>&1)

http_code=$(echo "$test_response" | tail -n1)
test_body=$(echo "$test_response" | head -n-1)

if [ "$http_code" != "200" ]; then
    print_error "Failed to connect to GitLab (HTTP $http_code)"
    print_error "Response: $test_body"
    print_info "Possible issues:"
    print_info "  1. Check if GitLab URL is correct: $GITLAB_URL"
    print_info "  2. Check if your Personal Access Token is valid"
    print_info "  3. If using self-signed SSL, set INSECURE_SSL=true in the script"
    print_info "  4. Check network connectivity: ping gitlab.mayer-it.net"
    exit 1
fi

gitlab_version=$(echo "$test_body" | jq -r '.version // "unknown"')
print_info "Connected to GitLab version: $gitlab_version"

# Fetch all projects from GitLab (paginated)
page=1
per_page=100
all_projects=()

while true; do
    response=$(curl -s $CURL_OPTS --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "${GITLAB_URL}/api/v4/projects?membership=true&per_page=${per_page}&page=${page}")
    
    # Check if response is valid JSON and parse project count
    project_count=$(echo "$response" | jq -e '. | length' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to fetch projects from GitLab. Please check your token and URL."
        print_error "Invalid JSON response received from GitLab API"
        exit 1
    fi
    
    # Check if we got any projects
    if [ "$project_count" -eq 0 ]; then
        break
    fi
    
    print_info "Fetched page $page: $project_count projects"
    
    # Add projects to array
    all_projects+=("$response")
    
    page=$((page + 1))
done

# Combine all pages and extract project information
projects_json=$(echo "${all_projects[@]}" | jq -s 'add')
total_projects=$(echo "$projects_json" | jq '. | length')

print_info "Found $total_projects projects"

# Counter for statistics
cloned_count=0
skipped_count=0
failed_count=0

# Process each project
echo "$projects_json" | jq -c '.[]' | while read -r project; do
    project_name=$(echo "$project" | jq -r '.path')
    project_namespace=$(echo "$project" | jq -r '.namespace.full_path')
    project_url=$(echo "$project" | jq -r '.ssh_url_to_repo // .http_url_to_repo')
    
    # Create namespace directory structure
    namespace_dir="$BACKUP_DIR/$project_namespace"
    project_dir="$namespace_dir/$project_name"
    
    # Skip if project already exists
    if [ -d "$project_dir" ]; then
        print_warning "Skipping $project_namespace/$project_name (already exists)"
        skipped_count=$((skipped_count + 1))
        continue
    fi
    
    # Create namespace directory
    mkdir -p "$namespace_dir"
    
    # Clone the project
    print_info "Cloning $project_namespace/$project_name..."
    
    # Use HTTPS URL with token authentication
    https_url=$(echo "$project" | jq -r '.http_url_to_repo')
    auth_url=$(echo "$https_url" | sed "s|https://|https://oauth2:${GITLAB_TOKEN}@|")
    
    # Set git config for SSL if needed
    if [ "$INSECURE_SSL" = true ]; then
        export GIT_SSL_NO_VERIFY=1
    fi
    
    if git clone "$auth_url" "$project_dir" 2>/dev/null; then
        print_info "Successfully cloned $project_namespace/$project_name"
        cloned_count=$((cloned_count + 1))
    else
        print_error "Failed to clone $project_namespace/$project_name"
        failed_count=$((failed_count + 1))
    fi
    
    # Unset git SSL config
    if [ "$INSECURE_SSL" = true ]; then
        unset GIT_SSL_NO_VERIFY
    fi
done

# Print summary
echo ""
print_info "=== Backup Summary ==="
print_info "Total projects found: $total_projects"
print_info "Newly cloned: $cloned_count"
print_info "Skipped (already exist): $skipped_count"
if [ $failed_count -gt 0 ]; then
    print_error "Failed: $failed_count"
fi

print_info "Backup completed!"
