namespace React\EventLoop;

use React\EventLoop\Tick\FutureTickQueue;
use React\EventLoop\Tick\NextTickQueue;
use React\EventLoop\Timer\Timer;
use React\EventLoop\Timer\TimerInterface;
use SplObjectStorage;

/**
 * An ext-libevent based event-loop.
 */
class LibEventLoop implements LoopInterface
{
    const MICROSECONDS_PER_SECOND = 1000000;

    private eventBase;
    private nextTickQueue;
    private futureTickQueue;
    private timerCallback;
    private timerEvents;
    private streamCallback;
    private streamEvents;
    private streamFlags = [];
    private readListeners = [];
    private writeListeners = [];
    private running;

    public function __construct()
    {
        let this->eventBase       = event_base_new();
        let this->nextTickQueue   = new NextTickQueue(this);
        let this->futureTickQueue = new FutureTickQueue(this);
        let this->timerEvents     = [];

        this->createTimerCallback();
        this->createStreamCallback();
    }

    /**
     * {@inheritdoc}
     */
    public function addReadStream(var stream, callable listener)
    {
        string key = (string)stream;

        if !isset(this->readListeners[key]) {
            let this->readListeners[key] = listener;
            this->subscribeStreamEvent(stream, EV_READ);
        }
    }

    /**
     * {@inheritdoc}
     */
    public function addWriteStream(var stream, callable listener)
    {
        string key = (string)stream;

        if !isset(this->writeListeners[key]) {
            let this->writeListeners[key] = listener;
            this->subscribeStreamEvent(stream, EV_WRITE);
        }
    }

    /**
     * {@inheritdoc}
     */
    public function removeReadStream(var stream)
    {
        string key = (string)stream;

        if isset(this->readListeners[key]) {
            unset(this->readListeners[key]);
            this->unsubscribeStreamEvent(stream, EV_READ);
        }
    }

    /**
     * {@inheritdoc}
     */
    public function removeWriteStream(var stream)
    {
        string key = (string)stream;

        if isset(this->writeListeners[key]) {
            unset(this->writeListeners[key]);
            this->unsubscribeStreamEvent(stream, EV_WRITE);
        }
    }

    /**
     * {@inheritdoc}
     */
    public function removeStream(var stream)
    {
        string key = (string)stream;

        if isset(this->streamEvents[key]) {
            var event;
            let event = this->streamEvents[key];

            event_del(event);
            event_free(event);

            unset(this->streamFlags[key]);
            unset(this->streamEvents[key]);
            unset(this->readListeners[key]);
            unset(this->writeListeners[key]);
        }
    }

    /**
     * {@inheritdoc}
     */
    public function addTimer(int interval, callable callback)
    {
        var timer;
        let timer = new Timer(this, interval, callback, false);

        this->scheduleTimer(timer);

        return timer;
    }

    /**
     * {@inheritdoc}
     */
    public function addPeriodicTimer(int interval, callable callback)
    {
        var timer;
        let timer = new Timer(this, interval, callback, true);

        this->scheduleTimer(timer);

        return timer;
    }

    /**
     * {@inheritdoc}
     */
    public function cancelTimer(<TimerInterface> timer)
    {
        var event;
        if this->isTimerActive(timer) {
            var timerKey = spl_object_hash(timer);
            let event = this->timerEvents[timerKey];

            event_del(event);
            event_free(event);

            unset(this->timerEvents[timerKey]);
        }
    }

    /**
     * {@inheritdoc}
     */
    public function isTimerActive(<TimerInterface> timer)
    {
        var timerKey = spl_object_hash(timer);
        return array_key_exists(timerKey, this->timerEvents);
    }

    /**
     * {@inheritdoc}
     */
    public function nextTick(callable listener)
    {
        this->nextTickQueue->add(listener);
    }

    /**
     * {@inheritdoc}
     */
    public function futureTick(callable listener)
    {
        this->futureTickQueue->add(listener);
    }

    /**
     * {@inheritdoc}
     */
    public function tick()
    {
        this->nextTickQueue->tick();

        this->futureTickQueue->tick();

        event_base_loop(this->eventBase, EVLOOP_ONCE | EVLOOP_NONBLOCK);
    }

    /**
     * {@inheritdoc}
     */
    public function run()
    {
        var flags;
        let this->running = true;

        while this->running {
            this->nextTickQueue->tick();

            this->futureTickQueue->tick();

            let flags = EVLOOP_ONCE;
            if !this->running || !this->nextTickQueue->isEmpty() || !this->futureTickQueue->isEmpty() {
                let flags = flags | EVLOOP_NONBLOCK;
            } elseif ( !this->streamEvents && !count(this->timerEvents) ) {
                break;
            }

            event_base_loop(this->eventBase, flags);
        }
    }

    /**
     * {@inheritdoc}
     */
    public function stop()
    {
        let this->running = false;
    }

    /**
     * Schedule a timer for execution.
     *
     * @param TimerInterface timer
     */
    private function scheduleTimer(<TimerInterface> timer)
    {
        var event = event_timer_new();
        var timerKey = spl_object_hash(timer);
        let this->timerEvents[timerKey] = event;

        event_timer_set(event, this->timerCallback, timer);
        event_base_set(event, this->eventBase);
        event_add(event, timer->getInterval() * self::MICROSECONDS_PER_SECOND);
    }

    /**
     * Create a new ext-libevent event resource, or update the existing one.
     *
     * @param stream  stream
     * @param integer flag   EV_READ or EV_WRITE
     */
    private function subscribeStreamEvent(var stream, int flag)
    {
        var event, flags, events;
        string key = (string)stream;

        if isset(this->streamEvents[key]) {
            let event = this->streamEvents[key];
            let this->streamFlags[key] = this->streamFlags[key] | flag;
            let flags = this->streamFlags[key];

            event_del(event);
            let events = EV_PERSIST | flag;
            event_set(event, stream, events, this->streamCallback);
        } else {
            let event  = event_new();
            let events = EV_PERSIST | flag;
            event_set(event, stream, events, this->streamCallback);
            event_base_set(event, this->eventBase);

            let this->streamEvents[key] = event;
            let this->streamFlags[key] = flag;
        }
        event_add(event);
    }

    /**
     * Update the ext-libevent event resource for this stream to stop listening to
     * the given event type, or remove it entirely if it's no longer needed.
     *
     * @param stream  stream
     * @param integer flag   EV_READ or EV_WRITE
     */
    private function unsubscribeStreamEvent(var stream, int flag)
    {
        var flags;
        var event;
        string key = (string)stream;
        let this->streamFlags[key] = this->streamFlags[key] & ~flag;
        let flags = this->streamFlags[key];

        if 0 === flags {
            this->removeStream(stream);

            return;
        }

        let event = this->streamEvents[key];

        event_del(event);
        event_set(event, stream, EV_PERSIST | flag, this->streamCallback);
        event_add(event);
    }

    /**
     * Create a callback used as the target of timer events.
     *
     * A reference is kept to the callback for the lifetime of the loop
     * to prevent "Cannot destroy active lambda function" fatal error from
     * the event extension.
     */
    private function createTimerCallback()
    {
        let this->timerCallback = [this, "callTimerCallback"];
    }

    /**
     * Timer 回调方法
     */
    public function callTimerCallback(var _, var _, <TimerInterface> timer)
    {
        call_user_func(timer->getCallback(), timer);

        // Timer already cancelled ...
        if !this->isTimerActive(timer) {
            return;

        // Reschedule periodic timers ...
        } elseif timer->isPeriodic() {
            var timerKey = spl_object_hash(timer);
            event_add(
                this->timerEvents[timerKey],
                timer->getInterval() * self::MICROSECONDS_PER_SECOND
            );

        // Clean-up one shot timers ...
        } else {
            this->cancelTimer(timer);
        }
    }

    /**
     * Create a callback used as the target of stream events.
     *
     * A reference is kept to the callback for the lifetime of the loop
     * to prevent "Cannot destroy active lambda function" fatal error from
     * the event extension.
     */
    private function createStreamCallback()
    {
        let this->streamCallback = [this, "callStreamCallback"];
    }

    /**
     * Timer 回调方法
     */
    public function callStreamCallback(var stream, int flags, var _)
    {
        string key = (string)stream;
        int readFlag, writeFlag;
        let readFlag  = ( EV_READ & flags );
        let writeFlag = ( EV_WRITE & flags );

        if (EV_READ === readFlag && isset(this->readListeners[key])) {
            call_user_func(this->readListeners[key], stream, this);
        }

        if (EV_WRITE === writeFlag && isset(this->writeListeners[key])) {
            call_user_func(this->writeListeners[key], stream, this);
        }
    }
}
