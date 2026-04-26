// Focused array cases: allocation, index write/read, bounds-sized ctor.
public class test_array {
  public static void main(String[] args) {
    int len = 4;
    int[] xs = new int[len];
    xs[0] = 1;
    xs[1] = 2;
    xs[2] = xs[0] + xs[1];
    System.out.println(xs[2]);
  }
}
