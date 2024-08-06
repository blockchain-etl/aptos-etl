# Use an official Python runtime alpine image as the base
FROM python:3.12.2-alpine3.19

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Add essential build tools
RUN apk add build-base linux-headers protoc

# Install any needed dependencies specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Create the protobuf schema
RUN protoc pubsub_range.proto --python_out=.

# Run app.py when the container launches
CMD ["python", "publish_ranges.py"]
