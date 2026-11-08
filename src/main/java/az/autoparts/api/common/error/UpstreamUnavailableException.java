package az.autoparts.api.common.error;

/**
 * An external dependency (e.g. the NHTSA vPIC VIN decoder) could not be reached
 * or answered with an error. Mapped to HTTP 503 by {@link GlobalExceptionHandler}.
 */
public class UpstreamUnavailableException extends RuntimeException {
    public UpstreamUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
