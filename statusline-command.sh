#!/bin/bash

# Claude Code Status Line Script
# Displays: Model • Directory • Branch • Context Size • Auto-compact %

# Read JSON input from stdin
input=$(cat)

# Extract basic information
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
transcript_path=$(echo "$input" | jq -r '.transcript_path')

# Change to working directory and get git branch
cd "$current_dir" 2>/dev/null
branch=$(git branch --show-current 2>/dev/null || echo "no-git")
dir_name=$(basename "$current_dir")

# Initialize token counters
total_input_tokens=0
total_cache_creation_tokens=0
total_cache_read_tokens=0
total_output_tokens=0

# Parse transcript file if it exists
if [[ -f "$transcript_path" ]]; then
    while IFS= read -r line; do
        if [[ -n "$line" && "$line" != "null" ]]; then
            # Extract token usage from each line
            usage=$(echo "$line" | jq -r '.message.usage // empty' 2>/dev/null)
            if [[ -n "$usage" && "$usage" != "null" ]]; then
                input_tokens=$(echo "$usage" | jq -r '.input_tokens // 0')
                cache_creation_tokens=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
                cache_read_tokens=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')
                output_tokens=$(echo "$usage" | jq -r '.output_tokens // 0')
                
                # Add to totals (ensure numeric values)
                [[ "$input_tokens" =~ ^[0-9]+$ ]] && total_input_tokens=$((total_input_tokens + input_tokens))
                [[ "$cache_creation_tokens" =~ ^[0-9]+$ ]] && total_cache_creation_tokens=$((total_cache_creation_tokens + cache_creation_tokens))
                [[ "$cache_read_tokens" =~ ^[0-9]+$ ]] && total_cache_read_tokens=$((total_cache_read_tokens + cache_read_tokens))
                [[ "$output_tokens" =~ ^[0-9]+$ ]] && total_output_tokens=$((total_output_tokens + output_tokens))
            fi
        fi
    done < "$transcript_path"
fi

# Calculate total context tokens
total_context_tokens=$((total_input_tokens + total_cache_creation_tokens + total_cache_read_tokens + total_output_tokens))

# Format token display
if [[ $total_context_tokens -gt 0 ]]; then
    # Format tokens with K/M suffix
    if [[ $total_context_tokens -ge 1000000 ]]; then
        tokens_display=$(echo "scale=1; $total_context_tokens / 1000000" | bc -l 2>/dev/null || echo "$total_context_tokens")
        tokens_display="${tokens_display}M"
    elif [[ $total_context_tokens -ge 1000 ]]; then
        tokens_display=$(echo "scale=1; $total_context_tokens / 1000" | bc -l 2>/dev/null || echo "$total_context_tokens")
        tokens_display="${tokens_display}K"
    else
        tokens_display="$total_context_tokens"
    fi
    
    # Calculate auto-compact percentage (assuming 200K context limit and 90% threshold)
    context_limit=200000
    auto_compact_threshold=$((context_limit * 90 / 100))  # 90% of 200K = 180K
    
    if [[ $total_context_tokens -ge $auto_compact_threshold ]]; then
        compact_percentage=100
    else
        compact_percentage=$((total_context_tokens * 100 / auto_compact_threshold))
    fi
    
    # Build status line with token information
    status_line="$model_name • $dir_name • $branch • ${tokens_display} tokens • ${compact_percentage}% to compact"
else
    # Fallback to basic status if no token data
    status_line="$model_name • $dir_name • $branch"
fi

echo "$status_line"