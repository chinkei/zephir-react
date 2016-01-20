namespace React\EventLoop;

class Factory
{
    public static function create() -> <LoopInterface>
    {
        return new LibEventLoop();
    }
}
