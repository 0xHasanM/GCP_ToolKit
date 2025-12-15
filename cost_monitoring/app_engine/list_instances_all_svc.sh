#!/bin/bash

# --- Parameter Setup ---
# Default to Queries Per Second (QPS)
MULTIPLIER=1
UNIT_LABEL="QPS"

# Check the first command-line argument to change the time unit
case "$1" in
  minute|min|m)
    MULTIPLIER=60
    UNIT_LABEL="QPM"
    ;;
  hour|hr|h)
    MULTIPLIER=3600
    UNIT_LABEL="QPH"
    ;;
  second|sec|s|"")
    # This case handles "second", "sec", "s", or no parameter given.
    MULTIPLIER=1
    UNIT_LABEL="QPS"
    ;;
  *)
    echo "Error: Invalid time unit '$1'. Please use 'hour', 'minute', or 'second'."
    exit 1
    ;;
esac

echo "🔍 Fetching instance activity (calculating for $UNIT_LABEL)..."

# --- Main Script Logic ---
# Get a list of all service IDs in the project
SERVICES=$(gcloud app services list --format="value(id)")

# Loop through each service
for SERVICE in $SERVICES
do
  printed_service_header=false
  VERSIONS=$(gcloud app versions list --service="$SERVICE" --format="value(id)")
  
  for VERSION in $VERSIONS
  do
    # Get the instance ID and its current Queries Per Second (QPS).
    # The calculation to QPM/QPH will be done in awk.
    INSTANCE_ACTIVITY_DATA=$(gcloud app instances list --service="$SERVICE" --version="$VERSION" --format="value(id,qps)")

    if [ -n "$INSTANCE_ACTIVITY_DATA" ]; then
      if [ "$printed_service_header" = false ]; then
        echo "=========================================================================="
        echo "▶️ Service: $SERVICE"
        echo "=========================================================================="
        printed_service_header=true
      fi

      INSTANCE_COUNT=$(echo "$INSTANCE_ACTIVITY_DATA" | wc -l)

      echo "  ✅ Version: $VERSION"
      echo "    Number of instances: $INSTANCE_COUNT"
      echo "    Instances:"
      
      # Pass the shell variables (MULTIPLIER, UNIT_LABEL) into awk.
      # awk will perform the calculation and formatting.
      echo "$INSTANCE_ACTIVITY_DATA" | awk \
        -v mult="$MULTIPLIER" \
        -v unit="$UNIT_LABEL" \
        '{
          activity_status = ($2 > 0) ? "Active (Processing)" : "Idle";
          calculated_rate = $2 * mult;
          printf "    - ID: %-45s Status: %-19s (%s: %.2f)\n", $1, activity_status, unit, calculated_rate
        }'
      
      echo ""
    fi
  done
done

echo "=========================================================================="
echo "✅ Script finished."
